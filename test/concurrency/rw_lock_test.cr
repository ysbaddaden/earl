require "../test_helper"
require "../../src/concurrency/rw_lock"
require "../../src/concurrency/wait_group"

module Earl
  class RWLockTest < Minitest::Test
    def test_lifetime
      rw = RWLock.new
      wg = WaitGroup.new(9)

      ary = [] of Int32
      counter = Atomic(Int64).new(0)

      # readers can run concurrently, but are mutually exclusive to writers (the
      # array can be safely read from):

      10.times do
        ::spawn(name: "reader") do
          100.times do
            rw.lock_read do
              ary.each { |i| counter.add(1) }
            end
            ::sleep(0)
          end
        end
      end

      # writers at mutually exclusive: they can safely modify the array

      5.times do
        ::spawn(name: "writer: increment") do
          100.times do
            rw.lock_write { 100.times { ary << ary.size } }
            ::sleep(0)
          end
          wg.done
        end
      end

      4.times do
        ::spawn(name: "writer: decrement") do
          100.times do
            rw.lock_write { 100.times { ary.pop? } }
            ::sleep(0)
          end
          wg.done
        end
      end

      wg.wait

      assert_equal (0..(ary.size - 1)).to_a, ary
      assert counter.lazy_get > 0
    end
  end
end
