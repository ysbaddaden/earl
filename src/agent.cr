require "./errors"
require "./logger"

module Earl
  module Agent
    enum Status
      Starting
      Running
      Stopping
      Stopped
      Crashed
      Recycling
    end

    # Finite state machine that maintains the `Status` of an `Agent`.
    class State
      # :nodoc:
      protected def initialize(@agent : Agent)
        @status = Status::Starting
      end

      def value : Status
        @status
      end

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

      def transition(new_status : Status) : Nil
        if can_transition?(new_status)
          Earl.logger.debug "#{@agent.class.name} transition from=#{@status} to=#{new_status}"
          @status = new_status
        else
          raise TransitionError.new("can't transition agent state from #{@status} to #{new_status}")
        end
      end
    end

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

    def trap(agent : A, exception : Exception?) : Nil
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
