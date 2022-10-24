require "../test_helper"
require "../../src/concurrency/unsafe_mutex"
require "../../src/concurrency/wait_group"

module Earl
  class UnsafeMutexTest < Minitest::Test
    def test_try_lock?
      m = UnsafeMutex.new
      assert m.try_lock?
      refute m.try_lock?
    end

    def test_lock
      state = 0
      m = UnsafeMutex.new
      m.lock

      ::spawn do
        state = 1
        m.lock
        state = 2
      end

      eventually { assert_equal 1, state }
      m.unlock
      eventually { assert_equal 2, state }
    end

    def test_unlock
      m = UnsafeMutex.new
      assert m.try_lock?
      m.unlock
      assert m.try_lock?
    end

    def test_synchronize
      mutex = UnsafeMutex.new
      wg = WaitGroup.new(100)
      counter = 0

      # uses a file to have IO to trigger fiber context switches
      tmp = File.tempfile("earl_unsafe_mutex", ".txt") do |file|
        100.times do
          ::spawn do
            100.times do
              mutex.synchronize do
                file.puts (counter += 1).to_s
              end
            end
            wg.done
          end
        end

        wg.wait
      end

      # no races when incrementing counter (parallelism)
      assert_equal 100 * 100, counter

      # no races when writing to file (concurrency)
      expected = (1..counter).join("\n") + "\n"
      assert_equal expected, File.read(tmp.path)
    ensure
      tmp.try(&.delete)
    end

    def test_suspend
      m = UnsafeMutex.new
      state = 0

      fiber = ::spawn do
        m.lock

        state = 1
        m.suspend
        state = 2
      end

      eventually { assert_equal 1, state }

      # it released the lock before suspending:
      eventually { assert m.try_lock? }
      m.unlock

      # it grabbed the lock on resume:
      fiber.enqueue
      eventually { assert_equal 2, state }
      refute m.try_lock?
    end

    # def test_suspend_with_timeout
    # end
  end
end
