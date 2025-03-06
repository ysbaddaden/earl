require "mutex"
require "./agent"

module Earl
  # A concurrency-safe registry of agents.
  #
  # - Agents of type `A` may (un)register from the registry at any time.
  # - Registered agents can be iterated with `#each`.
  # - Sent messages of type `M` are broadcasted to all registered agents.
  # - Failing to deliver a message to an agent will silently unregister it.
  #
  # ### Concurrency
  #
  # Relies on a copy-on-write array:
  # - (un)registering an agent will duplicate the current array (in a lock);
  # - iterations always iterate an immutable older reference to the array.
  #
  # This assumes that agents will (un)register themselves infrequently and
  # messages be sent much more often.
  class Registry(A, M)
    def initialize
      @mutex = Mutex.new(:unchecked)
      @subscriptions = [] of A
      @closed = false
    end

    # Registers an agent. Raises if the registry is closed.
    def register(agent : A) : Nil
      @mutex.synchronize do
        raise ClosedError.new if closed?
        dup(&.push(agent))
      end
    end

    # Unregisters an agent.
    def unregister(agent : A) : Nil
      @mutex.synchronize do
        dup(&.delete(agent)) unless closed?
      end
    end

    # Broadcasts a message to all registered agents at the time
    def send(message : M) : Nil
      each do |agent|
        begin
          agent.send(message)
        rescue ClosedError
          unregister(agent) unless closed?
        rescue ex
          agent.log.error { "failed to send to registered agent message=#{ex.message} (#{ex.class.name})" }
          unregister(agent) unless closed?
        end
      end

      Fiber.yield
    end

    # Iterates registered agents. Always iterates agents registered at the
    # moment the iteration is started. Newly registered agents won't be
    # iterated, when newly unregistered agents will be.
    def each : Nil
      raise ClosedError.new if closed?
      subscriptions = @subscriptions
      subscriptions.each { |agent| yield agent }
    end

    # NOTE: must be called within a `@mutex.synchronize` block!
    private def dup
      subscriptions = @subscriptions.dup
      yield subscriptions
      @subscriptions = subscriptions
    end

    # Closes the registry, preventing agents to register, then asks all
    # registered agents to stop.
    def stop : Nil
      @mutex.synchronize { @closed = true }
      @subscriptions.each do |agent|
        agent.stop rescue nil
      end
      @subscriptions.clear
    end

    def closed? : Bool
      @closed
    end
  end
end
