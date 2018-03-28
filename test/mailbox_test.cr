require "./test_helper"

private class Counter
  include Earl::Agent
  include Earl::Mailbox(Int32)

  getter value : Int32

  def initialize(@value = 0)
  end

  def call
    while increment = receive?
      @value += increment
    end
  end
end

module Earl
  class MailboxTest < Minitest::Test
    def test_send
      counter = Counter.new(0)
      counter.spawn

      counter.send(2)
      sleep 0
      assert_equal 2, counter.value

      counter.send(10)
      counter.send(23)
      counter.send(54)
      counter.stop
      sleep 0
      assert_equal 89, counter.value

      assert_raises(ClosedError) { counter.send(102) }
    end

    def test_receive
      counter = Counter.new(0)

      counter.send(1)
      counter.send(2)
      assert_equal 1, counter.receive
      assert_equal 2, counter.receive

      counter.spawn
      sleep 0
      counter.stop

      assert_raises(ClosedError) { counter.receive }
      assert_nil counter.receive?
    end
  end
end
