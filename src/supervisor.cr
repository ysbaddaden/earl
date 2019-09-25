require "mutex"
require "./agent"

module Earl
  # Supervises other agents.
  #
  # - Spawns agents in their dedicated `Fiber`.
  # - Recycles and restarts crashed agents.
  # - Eventually stops when all agents have stopped.
  class Supervisor
    include Agent
    include Logger

    def initialize
      @agents = [] of Agent
      @mutex = Mutex.new
      @done = Channel(Int32).new
    end

    # Adds an agent to supervise.
    def monitor(agent : Agent) : Nil
      if starting?
        @mutex.synchronize { @agents << agent }
      else
        raise ArgumentError.new("agents must be monitored before starting the supervisor")
      end
    end

    # Spawns all agents to supervise in their dedicated `Fiber`. Blocks until
    # all agents have stopped.
    def call
      agents = @agents
      count = agents.size

      agents.each do |agent|
        ::spawn do
          while running? && agent.starting?
            agent.start(link: self)
          end
        end
      end

      count.times { @done.receive? }
    end

    # Recycles and restarts crashed agents. Take note that an agent has stopped.
    def trap(agent : Agent, exception : Exception?) : Nil
      if exception
        Logger.error(agent, exception)
        log.error { "#{agent.class.name} crashed (#{exception.class.name})" }
        return agent.recycle if running?
      end

      @done.send(1)
      Fiber.yield
    end

    # Asks all supervised agents to stop.
    def terminate : Nil
      @agents.reverse_each do |agent|
        agent.stop if agent.running?
      end
      # @done.close
    end

    # Recycles all supervised agents.
    def reset : Nil
      @done = Channel(Int32).new
      @agents.each(&.recycle)
    end
  end
end
