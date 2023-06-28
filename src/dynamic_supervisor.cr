require "syn/core/mutex"
require "syn/core/wait_group"
require "./agent"

module Earl
  # Supervises dynamic agents.
  #
  # The list of monitored agents is dynamic. Agents may only be added after the
  # supervisor itself has started. Unlike `Supervisor` stopped agents will
  # be removed from supervision; agents will only be restarting when they
  # crash.
  #
  # Use a `DynamicSupervisor` to monitor agents that will be spawned by other
  # agents after the program has started, and that can be stopped and restarted
  # regularly. For example stateful sessions or an in-memory data source for
  # sporadic usages.
  #
  # - Spawns agents in their dedicated `Fiber`.
  # - Whenever a supervised agent stops, it will be removed from supervision.
  # - Whenever a supervised agent crashes, it will be recycled and restarted.
  # - The supervisor won't stop when all monitored agents have stopped. It must
  #   be explicitely told to stop (in which case it will stop all agents).
  class DynamicSupervisor
    include Agent
    include Logger

    def initialize
      @agents = Deque(Agent).new
      @mutex = Syn::Core::Mutex.new(:unchecked)
      @group = Syn::Core::WaitGroup.new(1) # supervisor must wait on itself (hence starting at 1)
    end

    # Adds an agent to supervise. The agent will be spawned immediately.
    def monitor(agent : Agent) : Nil
      raise ArgumentError.new("agents must be monitored after starting the dynamic supervisor") if starting?
      raise ArgumentError.new("can't monitor running agents") unless agent.starting?

      if message = monitor?(agent)
        raise ArgumentError.new(message)
      else
        spawn_agent(agent)
      end
    end

    protected def monitor?(agent : Agent) : String?
      @mutex.synchronize do
        return "can't monitor the same agent twice" if @agents.includes?(agent)
        @agents << agent
        nil
      end
    end

    protected def spawn_agent(agent : Agent) : Nil
      ::spawn do
        while running? && agent.starting?
          agent.start(link: self)
        end
      end
      @group.add(1)
    end

    # Waits until all supervised agents have stopped and the supervisor itself
    # is told to stop.
    def call
      @group.wait
    end

    # Recycles and restarts crashed agents. Removes stopped agent from
    # supervision.
    def trap(agent : Agent, exception : Exception?) : Nil
      if exception
        Logger.error(agent, exception)
        log.error { "worker crashed (#{exception.class.name})" }

        if running?
          agent.recycle
          return
        end
      end

      @mutex.synchronize do
        @agents.delete(agent)
      end

      @group.done # agent is done
      sleep(0.seconds)
    end

    # Asks all supervised agents to stop.
    def terminate : Nil
      @mutex.synchronize do
        @agents.reverse_each do |agent|
          agent.stop if agent.running?
        end
      end
      @group.done # supervisor is done
    end

    # Clears the list of supervised agents.
    def reset : Nil
      @group = Syn::Core::WaitGroup.new(1)
      @agents.clear
    end
  end
end
