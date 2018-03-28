require "./agent/state"

module Earl
  module Agent
    def state : State
      @state ||= State.new(self)
    end

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

    def spawn(*, link : Agent? = nil) : Nil
      ::spawn { start(link: link) }
    end

    abstract def call : Nil

    def stop : Nil
      state.transition(Status::Stopping)
      terminate
    end

    def terminate : Nil
    end

    def trap(agent : Agent, exception : Exception?) : Nil
    end

    def recycle : Nil
      state.transition(Status::Recycling) unless recycling?
      reset
      state.transition(Status::Starting)
    end

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
