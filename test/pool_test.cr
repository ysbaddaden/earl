require "./test_helper"

private class Worker
  include Earl::Artist(Int32)

  def initialize(@chaos = true)
  end

  def call(message)
    log.info { "received #{message}" }
    sleep 0
    raise "chaos monkey" if @chaos && rand(0..9) == 1
  end
end

module Earl
  class PoolTest < Minitest::Test
    def test_pool
      pool = Pool(Worker, Int32).new(5)

      spawn do
        999.times { |i| pool.send(i) }
        pool.stop
      end

      pool.start
    end

    def test_pool_new_agent_block
      called = false
      pool = Pool(Worker, Int32).new(5) { called = true; Worker.new(false) }
      pool.spawn
      eventually { called == true }
    end
  end
end
