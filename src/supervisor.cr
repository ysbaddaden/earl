require "mutex"
require "./agent"

module Earl
  class Supervisor
    include Agent
    include Logger

    def initialize
      @agents = [] of Agent
      @mutex = Mutex.new
      @done = Channel(Nil).new
    end

    def monitor(agent : Agent) : Nil
      if starting?
        @mutex.synchronize { @agents << agent }
      else
        raise ArgumentError.new("agents must be monitored before starting the supervisor")
      end
    end

    def call : Nil
      @agents.each do |agent|
        spawn do
          while agent.starting?
            agent.start(link: self)
          end
        end
      end

      until @done.closed?
        @done.receive?
      end
    end

    def trap(agent : Agent, exception : Exception?) : Nil
      if exception
        log.error { "#{agent.class.name} crashed message=#{exception.message} (#{exception.class.name})" }
        agent.recycle
      elsif !@done.closed?
        return @done.send(nil)
      end
      Fiber.yield
    end

    def terminate : Nil
      @agents.reverse_each do |agent|
        agent.stop # if agent.running?
      end
      @done.close
    end

    def reset : Nil
      @done = Channel(Nil).new
      @agents.each(&.recycle)
    end
  end
end
