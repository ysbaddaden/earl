require "mutex"
require "./actor"

module Earl
  # An actor that monitors other actors.
  #
  # A supervisor is given the task to start different actors, then monitor their
  # execution. Each actor will be spawned in their own `Fiber` and linked to the
  # supervisor: crashed actor will be recycled then restarted, and stopped
  # actors won't be monitored anymore.
  #
  # Supervisors assume that the actors they monitor override their `Actor#reset`
  # method to properly reset their values after a crash, otherwise the behavior
  # of restarted actors is undefined.
  #
  # Supervisors may be stopped; in this situation each monitored actor will be
  # asked to stop.
  #
  # You may use a supervisor to keep a service alive, even if it crashes, and
  # also prevent your main application from exiting until your service stops.
  # For example:
  #
  # ```
  # require "earl/supervisor"
  #
  # class Foo
  #   include Earl::Actor
  #
  #   def call
  #     # ...
  #   end
  # end
  #
  # class Bar
  #   include Earl::Actor
  #
  #   def call
  #     # ...
  #   end
  # end
  #
  # supervisor = Earl::Supervisor.new
  # supervisor.monitor(Foo.new)
  # supervisor.monitor(Bar.new)
  #
  # Signal::INT.trap { supervisor.stop }
  #
  # # block until either Ctrl+C or Foo and Bar both stop
  # supervisor.start
  # ```
  class Supervisor
    include Actor

    # Creates a new `Supervisor`.
    def initialize
      @actors = [] of Actor
      @mutex = Mutex.new
      @done = Channel(Nil).new
    end

    # Registers an actor to monitor. A supervisor requires actors to be
    # registered before it starts. Trying to monitor an actor after the
    # supervisor is started will raise an `ArgumentError` exception.
    #
    # Since a `Supervisor` is also an `Actor` it can monitor other supervisors.
    def monitor(actor : Actor) : Nil
      if starting?
        @mutex.synchronize { @actors << actor }
      else
        raise ArgumentError.new("actors must be monitored before starting the supervisor")
      end
    end

    # The actual supervisor. Spawns each previously registered actors, then
    # blocks until the actor is stopped, either explicitely or implicitely if
    # all its monitored actors are stopped.
    def call : Nil
      @actors.each do |actor|
        spawn do
          while actor.starting?
            actor.start(link: self)
          end
        end
      end

      until @done.closed?
        @done.receive?
      end
    end

    # If a monitored `Actor` crashes, the error will be logged then the actor
    # will be recycled and eventually restarted in its own Fiber.
    def trap(actor : Actor, exception : Exception?) : Nil
      if exception
        Earl.logger.error "#{actor.class.name} failed message=#{exception.message} (#{exception.class.name})"
        actor.recycle
      else
        @done.send(nil)
      end
    end

    # Asks monitored actors to stop.
    def terminate : Nil
      @actors.each(&.stop)
      @done.close
    end

    # Recycles all actors.
    def reset : Nil
      @done = Channel(Nil).new
      @actors.each(&.recycle)
    end
  end
end
