class Earl::CondVar
  # TODO: use Fiber::PointerLinkedListNode (Crystal >= 1.16)
  struct Waiting
    include Crystal::PointerLinkedList::Node

    def initialize(@fiber : Fiber)
    end

    def enqueue : Nil
      @fiber.enqueue
    end
  end

  def initialize
    @spin = Crystal::SpinLock.new
    @list = Crystal::PointerLinkedList(Waiting).new
  end

  def wait(mutex : Mutex) : Nil
    waiting = Waiting.new(Fiber.current)
    @spin.sync { @list.push(pointerof(waiting)) }

    mutex.unlock
    Fiber.suspend
    mutex.lock
  end

  def signal : Nil
    waiting = @spin.sync { @list.shift? }
    waiting.try(&.value.enqueue)
  end
end

class Earl::RWLock
  def initialize(protection : Mutex::Protection = :checked)
    @mutex = Mutex.new(protection)
    @cond = Earl::CondVar.new
    @readers = 0
  end

  def lock_read : Nil
    @mutex.synchronize do
      @readers += 1
    end
  end

  def unlock_read : Nil
    @mutex.synchronize do
      @readers -= 1
      @cond.signal if @readers == 0
    end
  end

  def lock_write : Nil
    @mutex.lock

    until @readers == 0
      @cond.wait(@mutex)
    end
  end

  def unlock_write : Nil
    @cond.signal
    @mutex.unlock
  end
end
