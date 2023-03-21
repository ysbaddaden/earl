# Alternative to `Atomic::Flag` that adds memory fences in addition to the
# atomic instructions & acquire/release memory ordering.
#
# Basically the atomic instructions tell the CPU to use an atomic operand on
# the CPU but also serves as a hint to the compiler (here LLVM) to not reorder
# instructions across the atomic. The fences on the other hand prevents weak CPU
# architectures (such as ARM) from reordering instructions across the fence too.
#
# The memory fences should be noop and optimized away on non weak CPU
# architectures such as x86/64.
#
# Another difference is the choice of the `:acquire` and `:release` memory
# orders for `#test_and_set` and `#clear` instead of the defaut
# `:sequentially_consistent` because Earl uses atomic flags as a lock mechanism.
#
# :nodoc:
struct Earl::AtomicFlag
  def initialize
    @value = 0_u8
  end

  def test_and_set : Bool
    test = Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :acquire, false) == 0_u8
    Atomic::Ops.fence(:acquire, false)
    test
  end

  def clear : Nil
    Atomic::Ops.fence(:release, false)
    Atomic::Ops.store(pointerof(@value), 0_u8, :release, true)
  end
end

# Similar to `AtomicFlag` but limited to a single usage: prevent a block of code
# to be invoked more than once, for example executing an initializer at most
# once.
struct Earl::Once
  def initialize
    @value = 0_u8
  end

  def call(& : ->) : Nil
    first = Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :sequentially_consistent, false) == 0_u8
    Atomic::Ops.fence(:sequentially_consistent, false)
    yield if first
  end
end
