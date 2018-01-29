require "../src/pool"
require "../src/mailbox"

class Worker
  include Earl::Actor
  include Earl::Mailbox(Int32)

  @@next_id = Atomic(Int32).new(1)
  getter id : Int32

  def initialize
    @id = @@next_id.add(1)
  end

  def call
    while m = receive?
      puts "Worker(#{id}): received #{m}"
      sleep rand(0.1..0.2)
      raise "chaos monkey" if rand(0..9) == 1
    end
  end
end

pool = Earl::Pool(Worker, Int32).new(10)

spawn do
  100.times do |i|
    pool.send(i)
  end
  pool.stop
end

pool.start
