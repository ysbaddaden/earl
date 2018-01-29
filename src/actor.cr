require "./errors"
require "./logger"

module Earl
  # An actor is a generic service object with a state.
  #
  #
  # ### Implementation
  #
  # A minimal actor implementation is a class or struct with a `#call` method
  # (no arguments, `Nil` return type). This method shall never be executed
  # directly, but through the `#start` or `#spawn` methods, that will transition
  # the actor's state or control the execution context.
  #
  # The `#call` method can execute whatever you want it to. For example it may
  # execute a long running task, start a loop to execute an action repeatedly,
  # or whatever else you want it to.
  #
  #
  # ### Start
  #
  # You can start an actor in two ways. `#start` transitions the actor's state
  # to `Status::Running` then executes the `#call` method and block until
  # `#call` returns. `#spawn` does exactly the same but only after starting a
  # new `Fiber`, thus doesn't block and returns immediately.
  #
  # When in doubt, use `#spawn` if you merely want to start a background service
  # and let it run; use `#start` if you want to control the execution context of
  # your actor, or are already within dedicated `Fiber`.
  #
  # You may *link* one actor to be notified when this actor crashes or exits,
  # which will execute the `#trap` method with the crashed or stopped actor
  # and the unhandled `Exception` if it crashed or `nil` if the actor terminated
  # properly.
  #
  #
  # ### Stop
  #
  # An actor will be stopped once the `#call` method returns.
  #
  # You can ask an actor to stop executing with `#stop`. This will transition
  # the actor's state to `Status::Stopping`, which the `#call` method must react
  # upon, for example by regularly checking if `#running?` returns true, to
  # quickly return.
  #
  # When the actor is stopping, the `#terminate` method will be called. An actor
  # may override this method to execute cleanup actions, notify other services,
  # or anything else needed.
  #
  #
  # ### State
  #
  # Actors can be started, stopped and recycled. They may also be crashed. This
  # involves transitioning to different states, which usually is:
  #
  #   1. `Status::Starting`, the initial state;
  #   2. `Status::Running` after calling `#start` (or `#spawn`);
  #   3. `Status::Stopping` after calling `#stop`;
  #   4. `Status::Stopped`, the definite state;
  #
  # But if the actor raised an unhandled exception, it's state will be
  # transitioned to `Status::Crashed` instead.
  #
  # A stopped or crashed actor may be recycled by calling `#recycle`, which will
  # transition the actor's state to `Status::Recycling` then execute its
  # `#reset` method that must return the actor's back to its original values. It
  # eventually transitions the actor's state back to `Status::Starting`, which
  # means the actor can be started again.
  #
  #
  # ### Example
  #
  # ```
  # class Sleeper
  #   include Earl::Actor
  #
  #   @counter = 0
  #
  #   def call
  #     while running?
  #       @counter += 1
  #       sleep(100.milliseconds)
  #     end
  #   end
  #
  #   def reset
  #     @counter = 0
  #   end
  # end
  #
  # sleeper = Sleeper.new
  # sleeper.spawn
  #
  # sleep(2)
  # sleeper.stop
  # sleeper.counter # => ~20
  # ```
  module Actor
    enum Status
      Starting
      Running
      Stopping
      Stopped
      Crashed
      Recycling
    end

    # A finite state machine that maintains the `Status` of an `Actor`.
    class State
      # :nodoc:
      protected def initialize(@actor : Actor)
        @status = Status::Starting
      end

      # Returns true if the current `Status` can be transitioned to the new one.
      # Returns false otherwise.
      def can_transition?(new_status : Status) : Bool
        case @status
        when .starting?
          new_status.running?
        when .running?
          new_status.stopping? || new_status.crashed?
        when .stopping?
          new_status.stopped? || new_status.crashed?
        when .stopped?, .crashed?
          new_status.recycling?
        when .recycling?
          new_status.starting?
        else
          false
        end
      end

      # Transitions to the new `Status`. Raises `TransitionError` if the
      # transition isn't allowed.
      def transition(new_status : Status) : Nil
        if can_transition?(new_status)
          Earl.logger.debug "#{@actor.class.name} transition from=#{@status} to=#{new_status}"
          @status = new_status
        else
          raise TransitionError.new("can't transition actor state from #{@status} to #{new_status}")
        end
      end

      def value : Status
        @status
      end

      def starting? : Bool
        @status.starting?
      end

      def running? : Bool
        @status.running?
      end

      def stopping? : Bool
        @status.stopping?
      end

      def stopped? : Bool
        @status.stopped?
      end

      def crashed? : Bool
        @status.crashed?
      end

      def recycling? : Bool
        @status.recycling?
      end
    end

    def state : State
      @state ||= State.new(self)
    end

    # Starts the actor.
    #
    # Transisions the actor's state to `Status::Running`, executes `#call` and
    # blocks until the method returns. Eventually calls `#stop` if it wasn't
    # called before, then transitions the actor's state to `Status::Stopped`.
    #
    # Use `#spawn` to start the actor within its own `Fiber`.
    #
    # You can *link* another actor that will be notified when this actor stops
    # by executing the `#trap` method, with two arguments, the first one being
    # this actor instance, and the second one the exception this actor raised
    # but didn't handle.
    def start(*, link : Actor? = nil) : Nil
      state.transition(Status::Running)
      begin
        call
      rescue ex
        state.transition(Status::Crashed)
        link.trap(self, ex) if link
      else
        link.trap(self, nil) if link
        stop if state.running?
        state.transition(Status::Stopped)
      end
    end

    # Identical to `#start` but starts the actor within its own `Fiber` and
    # returns immediately.
    def spawn(*, link : Actor? = nil) : Nil
      ::spawn { start(link: link) }
    end

    # The main body of an actor.
    #
    # It must be implemented for the actor to do anything. It may execute a
    # single action then simply return, which will cause the actor to be
    # stopped, it may enter a loop, or anything else you want it to.
    #
    # If running a loop, or if the actor can be interrupted, the method should
    # return whenever `#running?` becomes false, which means the actor should
    # stop.
    abstract def call : Nil

    # Transitions the actor's state to `Status::Stopping` and calls
    # `#terminate`.
    def stop : Nil
      state.transition(Status::Stopping)
      terminate
    end

    # Executed when the actor is stopping. Does nothing by default.
    #
    # NOTE: must be overriden if the actor needs to cleanup before it's stopped.
    def terminate : Nil
    end

    # Executed when a linked actor stopped. If the linked actor raised an
    # unhandled exception, then *exception* will be defined, otherwise it will
    # be `nil`.
    #
    # Does nothing by default.
    #
    # NOTE: must be overriden if the actor links itself to other actors, and
    # needs to react upon it.
    # TODO: consider crashing the actor by default (instead of noop) in order to
    # bubble errors?
    def trap(actor : A, exception : Exception?) : Nil
    end

    # Transitions the actor's state to `Status::Recycling` then executes
    # `#reset` so an actor may reset its internal values or connections.
    # Eventually returns the actor's state to `Status::Starting` so it can be
    # restarted.
    def recycle
      state.transition(Status::Recycling) unless recycling?
      reset
      state.transition(Status::Starting)
    end

    # Executed when the actor is being recycled. The actor should reset or
    # cleanup its internal state to return to a fresh state, so it can be
    # restarted properly.
    #
    # NOTE: must be overriden if the actor is meant to be recycled (e.g.
    # monitored by `Supervisor`) and has some internal values or connections
    # to reset.
    def reset
    end

    # Delegates to `#state`.
    def starting? : Bool
      state.starting?
    end

    # Delegates to `#state`.
    def running? : Bool
      state.running?
    end

    # Delegates to `#state`.
    def stopping? : Bool
      state.stopping?
    end

    # Delegates to `#state`.
    def stopped? : Bool
      state.stopped?
    end

    # Delegates to `#state`.
    def crashed? : Bool
      state.crashed?
    end

    # Delegates to `#state`.
    def recycling? : Bool
      state.recycling?
    end
  end
end
