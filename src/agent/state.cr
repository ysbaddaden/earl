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

      # The agent has been asked to stop. Previous state must be `Running` to be
      # able to transition.
      Stopping

      # The agent has stopped. Previous state must be `Stopping` to be able to
      # transition.
      Stopped

      # The agent has crashed (i.e. raised an exception). Previous state must be
      # `Running` or `Stopping` to be able to transition.
      Crashed

      # The agent has been told to recycle. Previous state must be `Stopped` or
      # `Crashed` to be able to transition.
      Recycling
    end

    # :nodoc:
    #
    # Finite state machine that maintains the `Status` of an `Agent`.
    struct State
      def initialize
        @status = Atomic(Status).new(Status::Starting)
      end

      def value : Status
        @status.get(:relaxed)
      end

      def transition(agent : Agent, new_status : Status) : Nil
        old_status = @status.get(:relaxed)

        loop do
          if can_transition?(old_status, new_status)
            agent.log.debug { "transition from=#{old_status} to=#{new_status}" }
            old_status, success = @status.compare_and_set(old_status, new_status, :acquire_release, :relaxed)
            break if success
          else
            agent.log.error { "transition error from=#{old_status} to=#{new_status}" }
            raise TransitionError.new("can't transition agent #{agent.class.name} state from #{old_status} to #{new_status}")
          end
        end
      end

      private def can_transition?(old_status : Status, new_status : Status) : Bool
        case old_status
        in Status::Starting
          new_status == Status::Running
        in Status::Running
          new_status == Status::Stopping || new_status == Status::Crashed
        in Status::Stopping
          new_status == Status::Stopped || new_status == Status::Crashed
        in Status::Stopped, Status::Crashed
          new_status == Status::Recycling
        in Status::Recycling
          new_status == Status::Starting
        end
      end
    end
  end
end
