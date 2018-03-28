require "./test_helper"

class Worker
  include Earl::Artist(Int32)

  def call(message)
    log.info "received #{message}"
    sleep 0
    raise "chaos monkey" if rand(0..9) == 1
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
  end
end
