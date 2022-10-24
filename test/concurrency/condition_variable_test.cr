require "../test_helper"
require "../../src/concurrency/unsafe_mutex"
require "../../src/concurrency/condition_variable"

module Earl
  class ConditionVariableTest < Minitest::Test
    def test_signal
      m = UnsafeMutex.new
      c = ConditionVariable.new
      done = waiting = 0

      100.times do
        ::spawn do
          m.synchronize do
            waiting += 1
            c.wait(pointerof(m))
            done += 1
          end
        end
      end
      eventually { assert_equal 100, waiting }

      # resume fibers one by one
      0.upto(99) do |i|
        assert_equal i, done
        c.signal
        ::sleep(0)
      end

      eventually { assert_equal 100, done }
    end

    def test_broadcast
      m = UnsafeMutex.new
      c = ConditionVariable.new
      done = waiting = 0

      100.times do
        ::spawn do
          m.synchronize do
            waiting += 1
            c.wait(pointerof(m))
            done += 1
          end
        end
      end
      eventually { assert_equal 100, waiting }
      assert_equal 0, done

      # resume all fibers at once
      c.broadcast
      eventually { assert_equal 100, done }
    end

    def test_producer_consumer
      mutex = UnsafeMutex.new
      cond = ConditionVariable.new
      state = -1

      ::spawn(name: "consumer") do
        mutex.synchronize do
          loop do
            cond.wait(pointerof(mutex))
            assert_equal 1, state
            state = 2
          end
        end
      end

      ::spawn(name: "producer") do
        mutex.synchronize { state = 1 }
        cond.signal
      end

      eventually { assert_equal 2, state }
    end
  end
end
