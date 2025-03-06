require "wait_group"

module Earl
  # :nodoc:
  module Logger
    # :nodoc:
    class_getter monitor : Monitor = Monitor.new

    Earl.application.monitor(@@monitor)

    # Traps async log dispatchers, and restarts them if they happen to crash for
    # as long as `Earl.application` is running.
    #
    # We don't use an actual `Supervisor` because logs must be started as soon
    # as possible (not delayed until the supervisor starts) and must live for as
    # long as possible, and thus not stopped when `Earl.application` exits.
    #
    # :nodoc:
    class Monitor
      include Earl::Agent

      def initialize
        @group = WaitGroup.new(1)
      end

      def call : Nil
        @group.wait
      end

      # TODO: implement maximum restart intensity
      def trap(agent : Agent, exception : Exception?) : Nil
        return unless exception

        agent.log.error(exception: exception) { "error" }
        log.error { "log dispatcher crashed (#{exception.class.name})" }

        if running?
          agent.recycle
          agent.spawn
        end

        sleep(0.seconds)
      end

      def terminate : Nil
        @group.done
      end

      def recycle : Nil
        @group = WaitGroup.new(1)
      end
    end
  end
end
