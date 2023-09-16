require "syn/core/mutex"
require "syn/core/wait_group"
require "./agent"

module Earl
  # Supervises other agents.
  #
  # The list of monitored agents is fixed and all agents must be added to the
  # supervisor before the supervisor starts.
  #
  # Use a `Supervisor` to monitor long lived agents that shall be spawned before
  # the program starts and expectd expected to stay alive for the whole duration
  # of the program, or at worst will stop by themselves after some time and
  # won't ever need to be restarted.
  #
  # - Spawns agents in their dedicated `Fiber`.
  # - Recycles and restarts crashed agents.
  # - Eventually stops when all agents have stopped.
  class Supervisor
    include Agent

    def initialize
      @agents = [] of Agent
      @mutex = Syn::Core::Mutex.new
      @group = Syn::Core::WaitGroup.new
    end

    # Adds an agent to supervise. The agent will be started when the supervisor
    # is started.
    def monitor(agent : Agent) : Nil
      raise ArgumentError.new("agents must be monitored before starting the supervisor") unless starting?
      raise ArgumentError.new("can't monitor running agents") unless agent.starting?

      if message = monitor?(agent)
        raise ArgumentError.new(message)
      end
    end

    protected def monitor?(agent : Agent) : String?
      @mutex.synchronize do
        return "can't monitor the same agent twice" if @agents.includes?(agent)
        @agents << agent
        nil
      end
    end

    # Spawns all agents to supervise in their dedicated `Fiber`. Blocks until
    # all agents have stopped.
    def call : Nil
      @agents.each { |agent| spawn_agent(agent) }
      @group.wait
    end

    protected def spawn_agent(agent : Agent) : Nil
      ::spawn do
        while running? && agent.starting?
          agent.start(link: self)
        end
      end
      @group.add(1)
    end

    # Recycles and restarts crashed agents. Take note that an agent has stopped.
    def trap(agent : Agent, exception : Exception?) : Nil
      if exception
        agent.log.error(exception: exception) { "error" }
        log.error { "worker crashed (#{exception.class.name})" }

        if running?
          agent.recycle
          return
        end
      end

      @group.done
      sleep(0.seconds)
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
