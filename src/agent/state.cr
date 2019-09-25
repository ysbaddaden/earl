require "../errors"

module Earl
  module Agent
    # The different statuses an agent can be in.
    enum Status
      # Initial state. May return to this state after `Recycling`.
      Starting

      # The agent was started and is still running. Previous state must be
      # `Starting` to be able to transition.
      Running

      # The agent has been asked to stop. Previous state must be
      # `Running` to be able to transition.
      Stopping

      # The agent has stopped. Previous state must be `Stopping` to be able to
      # transition.
      Stopped

      # The agent has crashed (i.e. raised an exception). Previous state must be
      # `Running`, `Stopping` or `Crashed` to be able to transition.
      Crashed

      # The agent has been told to recycle. Previous state must be `Stopped` or
      # `Crashed` to be able to transition.
      Recycling
    end

    # :nodoc:
    class State
      # Finite state machine that maintains the `Status` of an `Agent`.

      def initialize(@agent : Agent)
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
          Logger.debug(@agent) { "transition from=#{@status} to=#{new_status}" }
          @status = new_status
        else
          raise TransitionError.new("can't transition agent state from #{@status} to #{new_status}")
        end
      end
    end
  end
end

require "../logger"
