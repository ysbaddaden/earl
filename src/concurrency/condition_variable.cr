require "./spin_lock"
require "./unsafe_mutex"
require "./wait_list"

module Earl
  # Synchronize execution of concurrently running fibers.
  #
  # This can be used to replace polling with a waiting list that can be resumed
  # when resources are available, while still behaving inside a mutually
  # exclusive context: when a waiting fiber is resumed, the mutex will be
  # locked.
  #
  # :nodoc:
  struct ConditionVariable
    def initialize
      @spin = SpinLock.new
      @waiting = WaitList.new
    end

    # Suspends the current fiber. The mutex is unlocked before the fiber is
    # suspended and will be locked again after the fiber is resumed and before
    # the function returns.
    def wait(mutex : Pointer(UnsafeMutex)) : Nil
      current = Fiber.current
      @spin.synchronize { @waiting.push(current) }
      mutex.value.suspend
    end

    # def wait(mutex : Pointer(UnsafeMutex), timeout : Time::Span) : Bool
    #   current = Fiber.current
    #   @spin.synchronize { @waiting.push(current) }
    #   mutex.value.suspend(timeout)
    # end

    # Enqueues one waiting fiber. Does nothing if there aren't any waiting
    # fiber.
    def signal : Nil
      if fiber = @spin.synchronize { @waiting.shift? }
        fiber.enqueue
      end
    end

    # Enqueues all waiting fibers at once. Does nothing if there aren't any
    # waiting fiber.
    def broadcast : Nil
      @spin.synchronize do
        @waiting.each(&.enqueue)
        @waiting.clear
      end
    end
  end
end
