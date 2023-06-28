require "syn/core/once"
require "./core_ext/crystal_at_exit_handlers"
require "./supervisor"

module Earl
  # A singleton `Supervisor` accessible as `Earl.application` with additional
  # features suited for programs:
  #
  # - traps the SIGINT and SIGTERM signals to exit cleanly;
  # - adds an `at_exit` handler to ask supervised agents to stop gracefully.
  #
  # Programs must always start `Earl::Application`; some Earl agents (e.g. log
  # agents) expect that `Earl.application` will be started. It can be spawned
  # in the background (and forgotten) or better be leveraged to monitor the
  # program's agents and block the main `Fiber` until the program is told to
  # terminate, which is recommended.
  #
  # TODO: support windows
  class Application < Supervisor
    @once = Syn::Core::Once.new

    # List of POSIX signals to trap. Defaults to `SIGINT` and `SIGTERM`. The
    # list may only be mutated prior to starting the application!
    def signals : Array(Signal)
      @signals ||= [Signal::INT, Signal::TERM]
    end

    # Traps signals. Adds an `at_exit` handler then delegates to `Supervisor`
    # which will block until all supervised actors are asked to terminate.
    def call : Nil
      @once.call do
        signals.each do |signal|
          signal.trap do
            log.debug { "received SIG#{signal} signal" }
            Fiber.yield
            exit
          end
        end

        # At exit handlers are run in reverse order, but we need this handler to
        # run after previously setup handler have been set (e.g.
        # minitest/autorun), so we prepend it the list.
        Crystal::AtExitHandlers.__earl_prepend do
          stop if running?
        end

        super
      end
    end
  end

  @@application = Application.new

  # Accessor to the `Application` singleton.
  def self.application : Application
    @@application
  end
end
