require "../errors"

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
