require "./supervisor"
require "./concurrency/atomic_flag"

module Earl
  # A singleton `Supervisor` accessible as `Earl.application` with additional
  # features suited for programs:
  #
  # - traps the SIGINT and SIGTERM signals to exit cleanly;
  # - adds an `at_exit` handler to ask supervised agents to stop gracefully.
  #
  # The `Logger` agent, among other possible agents, expect that
  # `Earl.application` will be started. Programs must always start it. Either
  # spawned in the background (and forgotten) or leveraged to monitor the
  # program agents, and block the main `Fiber` until the program is told to
  # terminate.
  class Application < Supervisor
    # :nodoc:
    protected def initialize
      @once = Earl::Once.new
      super
    end

    # List of POSIX signals to trap. Defaults to `SIGINT` and `SIGTERM`. The
    # list may only be changed prior to starting the application.
    def signals
      @signals ||= [Signal::INT, Signal::TERM]
    end

    # Traps signals. Adds an `at_exit` handler then delegates to `Supervisor`
    # which will block until all supervised actors are asked to terminate.
    def call
      @once.call do
        signals.each do |signal|
          signal.trap do
            log.debug { "received SIG#{signal} signal" }
            Fiber.yield
            exit
          end
        end

        at_exit do
          stop if running?
        end

        super
      end
    end
  end

  @@application = Application.new

  # Accessor to the `Application` singleton.
  def self.application
    @@application
  end
end
