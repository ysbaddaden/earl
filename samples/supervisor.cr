require "../src/earl"
Earl.application.spawn

alias Message = Int32

class Consumer
  include Earl::Artist(Message)

  def initialize(@id : Int32)
  end

  def call(message)
    puts "client id=#{@id} received=#{message} (#{message.class.name})"
  end
end

class Producer
  include Earl::Agent

  def initialize
    @i = 0
    @consumers = [] of Consumer
  end

  def register(agent : Consumer)
    @consumers << agent
  end

  def unregister(agent : Consumer)
    @consumers.delete(agent)
  end

  def call
    while running?
      @consumers.each(&.send(@i += 1))
      sleep 0.5
      raise "chaos monkey" if rand(0..9) == 1
    end
  end

  def terminate
  end

  def reset
    @i = 0
  end
end

supervisor = Earl::Supervisor.new

queue = Producer.new
supervisor.monitor(queue)

2.times do |id|
  client = Consumer.new(id)
  queue.register(client)
  client.spawn
end

Signal::INT.trap do
  if supervisor.stopping?
    puts "forced interruption"
    exit 1
  else
    supervisor.stop
  end
end

supervisor.start
