require "./lock"
require "./spin_lock"
require "./wait_list"

module Earl
  # An unchecked, Fiber aware, mutually exclusive lock.
  #
  # Prevents two or more fibers to access the same non concurrent piece of code
  # (e.g. mutating a shared object) at the same time.
  #
  # This a smaller alternative to the `::Mutex` class in stdlib, that allocates
  # many classes (Deque, Crystal::SpinLock) and has lots of safety checks. The
  # drawback is that this mutex is unchecked: if a fiber holding the lock tries
  # to acquire the lock again, then you will have a deadlock situation, and your
  # program will hang forever.
  #
  # :nodoc:
  struct UnsafeMutex
    include Lock

    def initialize
      @held = AtomicFlag.new
      @spin = SpinLock.new
      @blocking = WaitList.new
    end

    # Returns true if it acquired the lock, otherwise immediately returns false.
    #
    # Returns false even if the current fiber had previously acquired the lock,
    # but won't cause a deadlock situation.
    #
    # NOTE: the mutex is unchecked!
    def try_lock? : Bool
      @held.test_and_set
    end

    # Acquires the lock, suspending the current fiber until the lock can be
    # acquired.
    #
    # NOTE: the mutex is unchecked!
    def lock : Nil
      __lock { @spin.suspend }
    end

    # # Identical to `#lock` but aborts if the lock couldn't be acquired until
    # # timeout is reached, in which case it returns false.
    # def lock(timeout : Time::Span) : Bool
    #   ret = true
    #   __lock { ret = @spin.suspend(timeout) }
    #   ret
    # end

    private def __lock(&)
      # try to acquire lock (without spin lock):
      return if try_lock?

      current = Fiber.current

      # need exclusive access to re-check 'held' then manipulate 'blocking'
      # based on the CAS result:
      @spin.lock

      # must loop because a wakeup may be concurrential, and another lock or
      # trylock already acquired the lock:
      until try_lock?
        @blocking.push(current)
        yield
      end

      @spin.unlock
    end

    # Releases the lock. Can be unlocked from any Fiber, not just the one that
    # acquired the lock.
    def unlock : Nil
      # need exclusive access because we modify both 'held' and 'blocking' that
      # could introduce a race condition with lock:
      @spin.lock

      # removes the lock (assumes the current fiber holds the lock):
      @held.clear

      # wakeup next blocking fiber (if any):
      if fiber = @blocking.shift?
        @spin.unlock
        fiber.enqueue
      else
        @spin.unlock
      end
    end

    # # Identical to `#synchronize` but aborts if the lock couldn't be acquired
    # # until timeout is reached, in which case it returns false.
    # def synchronize(timeout : Time::Span, &) : Bool
    #   if lock(timeout)
    #     begin
    #       yield
    #     ensure
    #       unlock
    #     end
    #     true
    #   else
    #     false
    #   end
    # end
  end
end
