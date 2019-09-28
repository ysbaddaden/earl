require "atomic"
require "mutex"

module Earl
  struct RWLock
    def initialize
      @reader_count = Atomic(Int32).new(0)
      @pending_writer = Atomic(Int32).new(0)
      @writer = Mutex.new
    end

    def lock_read
      loop do
        # wait until writer lock is released:
        while @pending_writer.get == 1
          Fiber.yield
        end

        # try to add a reader:
        @reader_count.add(1)

        # success: no writer acquired the lock (done)
        return if @pending_writer.get == 0

        # failure: a writer acquired the lock (try again)
        @reader_count.sub(1)
      end
    end

    def unlock_read
      # just remove a reader:
      @reader_count.sub(1)
    end

    def lock_write
      # acquire the single writer lock:
      @writer.lock

      # tell readers there is a pending writer:
      @pending_writer.set(1)

      # wait until all readers are unlocked (or waiting):
      until @reader_count.get == 0
        Fiber.yield
      end
    end

    def unlock_write
      # tell readers there is no longer a pending writer:
      @pending_writer.set(0)

      # release the single writer lock:
      @writer.unlock
    end
  end
end
