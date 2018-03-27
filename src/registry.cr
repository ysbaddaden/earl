require "mutex"
require "./agent"

module Earl
  module Registry(A, M)
    # The actual concurrency-safe registry object.
    #
    # Relies on a copy-on-write array: (un)registering an agent will duplicate
    # the current array (in a lock); iterations always iterate an immutable
    # older reference to the array. This assumes that agents will (un)register
    # themselves infrequently and messages be sent much more often.
    class Registry(A, M)
      def initialize
        @mutex = Mutex.new
        @subscriptions = [] of A
        @closed = false
      end

      def register(agent : A) : Nil
        @mutex.synchronize do
          raise ClosedError.new if closed?
          dup(&.push(agent))
        end
      end

      def unregister(agent : A) : Nil
        @mutex.synchronize do
          dup(&.delete(agent)) unless closed?
        end
      end

      def send(message : M) : Nil
        each do |agent|
          begin
            agent.send(message)
          rescue ClosedError
            unregister(agent) unless closed?
          rescue ex
            Logger.error(agent) { "failed to send to registered agent message=#{ex.message} (#{ex.class.name})" }
            unregister(agent) unless closed?
          end
        end
      end

      def each
        raise ClosedError.new if closed?
        subscriptions = @subscriptions
        subscriptions.each { |agent| yield agent }
      end

      private def dup
        subscriptions = @subscriptions.dup
        yield subscriptions
        @subscriptions = subscriptions
      end

      def stop
        @mutex.synchronize { @closed = true }
        @subscriptions.each(&.stop)
        @subscriptions.clear
      end

      def closed? : Bool
        @closed
      end
    end

    def registry : Registry(A, M)
      @registry ||= Registry(A, M).new
    end

    def register(agent : A) : Nil
      registry.register(agent)
    end

    def unregister(agent : A) : Nil
      registry.unregister(agent)
    end
  end
end
