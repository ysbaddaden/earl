require "log"

module Earl
  module Logger
    # Alternative to `Log::AsyncDispatcher` but as an `Agent` that can be
    # supervised.
    #
    # Unlike `Log::AsyncDispatcher` we don't setup a finalizer because the
    # dynamic supervisor will always keep a reference to the agent until the
    # agent is explicitely stopped.
    #
    # TODO: implement a custom supervisor to monitor agents that may be used
    #       before the earl application starts (?)
    #
    # :nodoc:
    class Dispatcher
      include ::Log::Dispatcher
      include Earl::Agent
      include Earl::Mailbox({::Log::Entry, ::Log::Backend})

      def initialize
        # avoid closing the mailbox, as some logs sent while the program ends
        # would raise an exception because the mailbox is closed
        @mailbox_close_on_stop = false
      end

      def call : Nil
        while msg = receive?
          entry, backend = msg
          backend.write(entry)
        end
      end

      # Implements `Log::Dispatcher#dispatch`
      @[AlwaysInline]
      def dispatch(entry : ::Log::Entry, backend : ::Log::Backend) : Nil
        send({entry, backend})
      end

      def close : Nil
        # supervisor may have already told the dispatcher to stop
        stop if running?
      end

      def terminate : Nil
        # wait until all log messages have been processed before returning
        queue = @mailbox.@queue.not_nil!

        until queue.empty?
          sleep(0.seconds)
        end
      end
    end
  end
end
