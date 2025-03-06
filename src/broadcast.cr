require "mutex"
require "./agent"

module Earl
  # Broadcast messages to a dynamic list of agents.
  #
  # - Agents of type `A` may subscribe and unsubscribe at any time.
  # - Registered agents can be safely iterated with `#each`.
  # - Sent messages of type `M` are broadcasted to all subscribed agents.
  # - Failing to deliver a message to an agent will silently unsubscribe the
  #   agent.
  #
  # `Broadcast` isn't an `Agent`: it doesn't execute anything and can't be
  # supervised; it's only a communication object. It can however be setup and
  # maintained by an `Agent`.
  #
  # WARNING: the implementation assumes that agents will (un)subscribe
  # infrequently and messages are sent much more frequently.
  @[Experimental("The Earl::Broadcast(A, M) API is under development")]
  class Broadcast(A, M)
    getter? closed : Bool

    def initialize
      @mutex = Mutex.new(:unchecked)
      @subscriptions = [] of A
      @closed = false
    end

    # Subscribes an agent. Raises `Earl::ClosedError` if the broadcast is closed.
    def subscribe(agent : A) : Nil
      @mutex.synchronize do
        raise ClosedError.new if closed?
        dup(&.push(agent))
      end
    end

    # Unsubcribes an agent.
    def unsubscribe(agent : A) : Nil
      @mutex.synchronize do
        dup(&.delete(agent)) unless closed?
      end
    end

    # Broadcasts a message to all the agents subscribed at the moment.
    def send(message : M) : Nil
      delivered_any = false

      each do |agent|
        begin
          agent.send(message)
          delivered_any = true
        rescue ClosedError
          unsubscribe(agent) unless closed?
        rescue ex
          agent.log.error { "failed to send to subscribed agent message=#{ex.message} (#{ex.class.name})" }
          unsubscribe(agent) unless closed?
        end
      end

      # give a chance to resume the other actors
      Fiber.yield if delivered_any
    end

    # Iterates subscribed agents. Always iterates agents subscribed at the
    # moment the iteration is started. Newly subscribed agents won't be
    # iterated, when newly unsubscribed agents will be.
    def each : Nil
      raise ClosedError.new if closed?

      subscriptions = @subscriptions
      subscriptions.each { |agent| yield agent }
    end

    # Closes the broadcast, preventing agents from subscribing.
    def close : Nil
      @mutex.synchronize do
        return if @closed

        @closed = true
        @subscriptions = [] of A
      end
    end

    # WARNING: must be called within `@mutex.synchronize { }`
    private def dup
      subscriptions = @subscriptions.dup
      yield subscriptions
      @subscriptions = subscriptions
    end
  end
end
