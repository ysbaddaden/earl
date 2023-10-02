require "log"

module Earl
  module Logger
    # Alternative to `Log::AsyncDispatcher` as an `Earl::Agent` that can be
    # supervised.

    # :nodoc:
    class AsyncDispatcher
      include ::Log::Dispatcher
      include Earl::Agent
      include Earl::Mailbox({::Log::Entry, ::Log::Backend})

      def initialize
        # never close the mailbox: logs sent while the program ends could raise
        # an exception because the mailbox is closed!
        @mailbox.close_on_stop = false
      end

      def finalize
        close
      end

      def call : Nil
        while msg = receive?
          entry, backend = msg
          backend.write(entry)
        end
      end

      @[AlwaysInline]
      def dispatch(entry : ::Log::Entry, backend : ::Log::Backend) : Nil
        send({entry, backend})
      end

      def close : Nil
        stop if running?
      end

      def terminate : Nil
        # wait until all log messages have been processed before returning
        until @mailbox.empty?
          sleep(0.seconds)
        end
      end
    end
  end
end
