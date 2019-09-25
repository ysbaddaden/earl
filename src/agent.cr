require "./agent/state"

module Earl
  # Earl's foundation module.
  #
  # Agents must implement the `#call` method that will be invoked when the agent
  # is started (or spawned).
  #
  # Agents have a state that is automatically maintained throughout an object
  # life. See `Status` for the different statuses. Agents can act upon their
  # state, for example loop while `.running?` returns true.
  module Agent
    protected def state : State
      @state ||= State.new(self)
    end

    # Starts the agent in the current `Fiber`. Blocks until the agent is
    # stopped or crashed.
    #
    # You may link another object to be notified if the agent crashed (raised an
    # exception) or stopped gracefully by calling its `#trap` method.
    def start(*, link : Agent? = nil) : Nil
      state.transition(Status::Running)
      begin
        call
      rescue ex
        state.transition(Status::Crashed)
        link.trap(self, ex) if link
      else
        link.trap(self, nil) if link
        stop if running?
        state.transition(Status::Stopped)
      end
    end

    # Spawns a new `Fiber` to start the agent in. Doesn't block and returns
    # immediately.
    def spawn(*, link : Agent? = nil, _yield = true) : Nil
      ::spawn { start(link: link) }
      Fiber.yield if _yield
    end

    # The logic of the `Agent`. May loop forever or until asked to stopped. If
    # an exception is raised the agent will be crashed; if the method returns
    # the agent will simply stop.
    abstract def call

    # Asks the agent to stop.
    def stop : Nil
      state.transition(Status::Stopping)
      terminate
    end

    # Called when the agent is asked to stop. Does nothing by default.
    def terminate : Nil
    end

    # Called when a linked agent has crashed (exception is set) or stoppped
    # (exception is nil). Does nothing by default.
    #
    # Always called from the passed *agent* `Fiber` and thus never runs
    # concurrently to the passed *agent* `#call` method. This means this method
    # will be called concurrently to this agent. Modifying *self* internal state
    # thus requires concurrency safe structures.
    def trap(agent : Agent, exception : Exception?) : Nil
    end

    # Tells the agent to recycle.
    def recycle : Nil
      state.transition(Status::Recycling) unless recycling?
      reset
      state.transition(Status::Starting)
    end

    # Called when the agent must be recycled. This must return the object to its
    # pristine state so it can be restarted properly. Does nothing by default.
    def reset : Nil
    end

    def starting? : Bool
      state.value.starting?
    end

    def running? : Bool
      state.value.running?
    end

    def stopping? : Bool
      state.value.stopping?
    end

    def stopped? : Bool
      state.value.stopped?
    end

    def crashed? : Bool
      state.value.crashed?
    end

    def recycling? : Bool
      state.value.recycling?
    end
  end
end
