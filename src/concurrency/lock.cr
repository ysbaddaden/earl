module Earl
  # :nodoc:
  module Lock
    # Acquires the lock. The execution of the current fiber is suspended until
    # the lock is acquired.
    abstract def lock : Nil

    # Releases the lock.
    abstract def unlock : Nil

    # Acquires the lock, yields, then releases the lock, even if the block
    # raised an exception.
    def synchronize(& : -> U) : U forall U
      lock
      yield
    ensure
      unlock
    end

    # Releases the lock, suspends the current Fiber, then acquires the lock
    # again when the fiber is resumed.
    #
    # The Fiber must be enqueued manually.
    def suspend : Nil
      unlock
      ::sleep
      lock
    end

    # # Identical to `#suspend` but if the fiber isn't manually resumed after
    # # timeout is reached, then the fiber will be resumed automatically.
    # def suspend(timeout : Time::Span) : Bool
    #   unlock
    #   ::sleep(timeout) # TODO: detect timeout and return false (otherwise true)
    #   lock
    # end
  end
end
