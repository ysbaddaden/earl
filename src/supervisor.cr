require "mutex"
require "./agent"

module Earl
  class Supervisor
    include Agent

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
        Earl.logger.error "#{agent.class.name} failed message=#{exception.message} (#{exception.class.name})"
        agent.recycle
      else
        @done.send(nil)
      end
    end

    def terminate : Nil
      @agents.each(&.stop)
      @done.close
    end

    def reset : Nil
      @done = Channel(Nil).new
      @agents.each(&.recycle)
    end
  end
end
