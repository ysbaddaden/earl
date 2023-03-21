require "./lock"
require "./atomic_flag"

module Earl
  # Tries to acquire an atomic lock by spining, trying to avoid slow thread
  # context switches that involve the kernel scheduler. Eventually fallsback to
  # a pause or yielding threads.
  #
  # This is a public alternative to the private Crystal::SpinLock in stdlib.
  #
  # The implementation is a NOOP unless you specify the `preview_mt` compile
  # flag.
  #
  # :nodoc:
  struct SpinLock
    include Lock

    {% if flag?(:preview_mt) %}
      # :nodoc:
      THRESHOLD = 100

      @flag = AtomicFlag.new

      def lock : Nil
        # fast path
        return if @flag.test_and_set

        # fixed busy loop to avoid a context switch:
        count = THRESHOLD
        until (count -= 1) == 0
          return if @flag.test_and_set
        end

        # blocking loop
        until @flag.test_and_set
          # LibC.pthread_yield
          Intrinsics.pause
        end
      end

      def unlock : Nil
        @flag.clear
      end
    {% else %}
      def lock : Nil
      end

      def unlock : Nil
      end
    {% end %}
  end
end
