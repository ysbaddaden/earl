require "./unsafe_mutex"
require "./condition_variable"

module Earl
  # A many readers, mutually exclusive writer lock.
  #
  # Allow readers to run concurrently but ensures that they will never run
  # concurrently to a writer. Writers are mutually exclusive to both readers
  # and writers.
  #
  # :nodoc:
  struct RWLock
    def initialize
      @mutex = UnsafeMutex.new
      @condition = ConditionVariable.new
      @readers_count = 0
    end

    def lock_read : Nil
      @mutex.synchronize do
        @readers_count += 1
      end
    end

    # def lock_read(timeout : Time::Span) : Bool
    #   if @mutex.lock(timeout)
    #     @readers_count += 1
    #     @mutex.unlock
    #     true
    #   else
    #     false
    #   end
    # end

    def lock_read(&) : Nil
      lock_read
      yield
    ensure
      unlock_read
    end

    # def lock_read(timeout : Time::Span, &) : Nil
    #   if lock_read(timeout)
    #     begin
    #       yield
    #     ensure
    #       unlock_read
    #     end
    #     true
    #   else
    #     false
    #   end
    # end

    def unlock_read : Nil
      @mutex.synchronize do
        if (@readers_count -= 1) == 0
          @condition.signal
        end
      end
    end

    def lock_write : Nil
      @mutex.lock
      until @readers_count == 0
        @condition.wait(pointerof(@mutex))
      end
    end

    # def lock_write(timeout : Time::Span) : Nil
    #   @mutex.lock
    #   until @readers_count == 0
    #     @condition.wait(pointerof(@mutex), timeout)
    #   end
    # end

    def lock_write(&) : Nil
      lock_write
      yield
    ensure
      unlock_write
    end

    # def lock_write(timeout : Time::Span, &) : Nil
    #   if lock_write(timeout)
    #     begin
    #       yield
    #     ensure
    #       unlock_write
    #     end
    #     true
    #   else
    #     false
    #   end
    # end

    def unlock_write : Nil
      @condition.signal
      @mutex.unlock
    end
  end
end
