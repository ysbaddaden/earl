require "mutex"

module Earl
  # Extends an `Actor` to hold a registry of actors of type `A`.
  #
  # The actor will then be capable to dispatch a message to all registered
  # actors or ask them all to stop.
  #
  # Actors must include `Mailbox(M)` to be capable to dispatch messages (of
  # type `M` obviously).
  module Registry(A, M)
    # The actual registry object.
    #
    # The registry object is a concurrency-safe data structure. Actors can be
    # registered and unregistered at any time from any `Fiber`, messages can be
    # sent safely to all currently registered objects while actors are
    # (un)registered, and so on.
    class Registry(A, M)
      def initialize
        @mutex = Mutex.new
        @subscriptions = [] of A
        @errors = [] of A
        @closed = false
      end

      # Registers an *actor* to the registry. Raises `ClosedError` if the
      # registry (or the actor) was stopped.
      def register(actor : A) : Nil
        @mutex.synchronize do
          raise ClosedError.new if closed?
          @subscriptions << actor
        end
      end

      # Unregisters an *actor* from the registry. Simply returns if the registry
      # (or the actor) was stopped.
      def unregister(actor : A) : Nil
        @mutex.synchronize do
          return if closed?
          @subscriptions.delete(actor)
        end
      end

      # Sends a *message* to all currently registered actors. If a failure
      # happens while delivering a message, the failing actor will be
      # unregistered.
      def send(message : M) : Nil
        @mutex.synchronize do
          raise ClosedError.new if closed?

          @subscriptions.each do |actor|
            begin
              actor.send(message)
            rescue Channel::ClosedError
              @errors << actor
            rescue ex
              @errors << actor
              Earl.logger.error "failed to send to registered actor=#{actor.class.name} message=#{ex.message} (#{ex.class.name})"
            end
          end

          @errors.each do |actor|
            @subscriptions.delete(actor)
          end

          @errors.clear
        end
      end

      # Closes the registry, unregisters and stops all registered actors.
      def stop
        @mutex.synchronize { @closed = true }
        @subscriptions.each(&.stop)
        @subscriptions.clear
      end

      def closed? : Bool
        @closed
      end
    end

    # The actual `Registry` object.
    def registry : Registry(A, M)
      @registry ||= Registry(A, M).new
    end

    # Asks the `Registry` object to register an `Actor`, so it will start
    # receiving messages as soon as possible. Race conditions may still happen
    # and a few messages may be skipped until the actor is fully registered.
    def register(actor : A) : Nil
      registry.register(actor)
    end

    # Asks the `Registry` object to unregisters an `Actor`, so it won't receive
    # messages anymore as soon as possible. Race conditions may still happen and
    # a few messages may still be received until the actor is fully
    # unregistered.
    def unregister(actor : A) : Nil
      registry.unregister(actor)
    end

    # :nodoc:
    # def stop
    #   registry.stop
    #   super
    # end
  end
end
