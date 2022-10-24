require "../test_helper"
require "../../src/concurrency/wait_group"

module Earl
  class WaitGroupTest < Minitest::Test
    def test_lifetime
      wg = WaitGroup.new
      wg.add(5)
      counter = Atomic(Int32).new(0)

      5.times do
        ::spawn do
          wg.done
          counter.add(1)
        end
      end

      wg.wait
      assert_equal 5, counter.get
    end
  end
end
