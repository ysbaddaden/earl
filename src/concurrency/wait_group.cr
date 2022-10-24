require "./condition_variable"
require "./unsafe_mutex"

module Earl
  # Suspend execution until other fibers are finished.
  #
  # :nodoc:
  struct WaitGroup
    def initialize(@counter : Int32 = 0)
      @mutex = UnsafeMutex.new
      @condition = ConditionVariable.new
    end

    # Increments the counter by how many fibers we want to wait for.
    #
    # Can be called at any time, allowing concurrent fibers to add more fibers
    # to wait for, but they must always do so before calling `#done` to
    # decrement the counter, to make sure that the counter may never
    # inadvertently reach zero before all fibers are done.
    def add(count : Int) : Nil
      @mutex.synchronize do
        @counter += count
      end
    end

    # Decrements the counter by one. Must be called by concurrent fibers once
    # they have finished processing. When the counter reaches zero, all waiting
    # fibers will be resumed.
    def done : Nil
      @mutex.synchronize do
        if (@counter -= 1) == 0
          @condition.broadcast
        end
      end
    end

    # Suspends the current fiber until the counter reaches zero, at which point
    # the fiber will be closed.
    #
    # Can be called from different fibers.
    def wait : Nil
      __wait { @condition.wait(pointerof(@mutex)) }
    end

    # Same as `#wait` but only waits until `timeout` is reached. Returns true if
    # the counter reached zero; returns false if timeout was reached.
    # def wait(timeout : Time::Span) : Bool
    #   __wait { return @condition.wait(pointerof(@mutex), timeout) }
    # end

    private def __wait : Nil
      @mutex.synchronize do
        until @counter == 0
          yield
        end
      end
    end
  end
end
