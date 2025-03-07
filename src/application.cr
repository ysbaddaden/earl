require "./core_ext/crystal_at_exit_handlers"
require "./supervisor"

module Earl
  # A singleton `Supervisor` accessible as `Earl.application` with additional
  # features to gracefully stop the application on exit.
  #
  # Programs must always start `Earl::Application` because some Earl agents
  # (for example `Log` agents) are only started by `Earl.application`.
  #
  # While it can be spawned in the background (and forgotten) we recommend to
  # use it to supervise your program's main agents and block the main `Fiber`
  # until the program terminates.
  #
  # TODO: support Windows
  class Application < Supervisor
    class_getter log = Log.for(self)

    @once = Atomic(Bool).new(false)

    # Application is a singleton object.
    protected def initialize
      super
    end

    # List of POSIX signals to trap. Defaults to `Signal::INT` and
    # `Signal::TERM`.
    #
    # WARNING: the list may only be mutated prior to starting the application!
    def signals : Array(Signal)
      @signals ||= [
        Signal::INT,
        Signal::TERM,
      ]
    end

    # Starts the application by deleting to the supervisor.
    #
    # Adds an `at_exit` handler to try and gracefully stop if the application
    # state is still running.
    #
    # Registers signal traps to gracefully stop when the signal is received, and
    # exit immediately when received while the agent state is no longer running.
    def call : Nil
      return if @once.swap(true, :sequentially_consistent)

      signals.each do |signal|
        signal.trap do
          if running?
            log.info { "received SIG#{signal} signal: exiting gracefully (send again to force exit)" }
            stop
          else
            log.warn { "received SIG#{signal} signal twice: exiting" }
            Fiber.yield
            exit
          end
        end
      end

      # At exit handlers are run in reverse order, but we need this handler to
      # run after previously setup handler have been set (for example
      # minitest/autorun in the test suite), so we prepend it the list.
      Crystal::AtExitHandlers.__earl_prepend do
        stop if running?
      end

      super
    end
  end

  # Accessor to the `Application` singleton.
  class_getter application : Application = Application.new
end
