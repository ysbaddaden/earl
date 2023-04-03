require "../test_helper"
require "../../src/scheduler/every"

class Earl::EveryTest < Minitest::Test
  def test_initializer
    Every.new(1.minute)
    Every.new(30.days)
    assert_raises(ArgumentError) { Every.new(59.seconds) }
  end

  def test_next
    Timecop.travel(Time.local(2023, 4, 2, 22, 6, 30)) do
      every = Every.new(1.minute)
      assert_equal Time.local(2023, 4, 2, 22, 7, 0), every.next
    end

    Timecop.travel(Time.local(2022, 12, 31, 23, 43, 27)) do
      every = Every.new(1.hour)
      assert_equal Time.local(2023, 1, 1, 0, 0, 0), every.next
    end
  end
end
