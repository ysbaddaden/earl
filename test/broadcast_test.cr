require "./test_helper"

private class Consumer
  include Earl::Agent
  include Earl::Mailbox(Int32)

  def call
    while message = receive?
      log.info { "received: #{message}" }
    end
  end
end

private class Producer
  include Earl::Agent

  def initialize
    @broadcast = Earl::Broadcast(Consumer, Int32).new
  end

  def subscribe(agent)
    @broadcast.subscribe(agent)
  end

  def unsubscribe(agent)
    @broadcast.unsubscribe(agent)
  end

  def call
    0.upto(999) do |i|
      @broadcast.send(i)
    end
  end

  def terminate
    @broadcast.close
  end
end

module Earl
  class BroadcastTest < Minitest::Test
    def test_registry
      producer = Producer.new

      5.times do
        consumer = Consumer.new
        producer.subscribe(consumer)
        consumer.spawn
      end

      producer.start
    end
  end
end
