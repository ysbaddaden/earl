require "syn/core/mutex"
require "syn/core/wait_group"
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
      @mutex = Syn::Core::Mutex.new
      @group = Syn::Core::WaitGroup.new
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
      @group.add(agents.size)

      agents.each do |agent|
        ::spawn do
          while running? && agent.starting?
            agent.start(link: self)
          end
        end
      end

      @group.wait
    end

    # Recycles and restarts crashed agents. Take note that an agent has stopped.
    def trap(agent : Agent, exception : Exception?) : Nil
      if exception
        Logger.error(agent, exception)
        log.error { "#{agent.class.name} crashed (#{exception.class.name})" }
        return agent.recycle if running?
      end

      @group.done
      Fiber.yield # TODO: sleep(0.seconds) ?
    end

    # Asks all supervised agents to stop.
    def terminate : Nil
      @agents.reverse_each do |agent|
        agent.stop if agent.running?
      end
    end

    # Recycles all supervised agents.
    def reset : Nil
      @group = Syn::Core::WaitGroup.new
      @agents.each(&.recycle)
    end
  end
end
