require "mutex"
require "wait_group"
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

    # :nodoc:
    class Supervised
      getter agent : Agent

      def initialize(@agent)
      end

      def ==(other : Agent) : Bool
        @agent == other
      end
    end

    def initialize
      @agents = [] of Supervised
      @mutex = Mutex.new
      @group = WaitGroup.new
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
        @agents << Supervised.new(agent)
        nil
      end
    end

    # Spawns all agents to supervise in their dedicated `Fiber`. Blocks until
    # all agents have stopped.
    def call : Nil
      @agents.each { |supervised| spawn_agent(supervised) }
      @group.wait
    end

    protected def spawn_agent(supervised : Supervised) : Nil
      ::spawn do
        agent = supervised.agent
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
      @agents.reverse_each do |supervised|
        agent = supervised.agent
        agent.stop if agent.running?
      end
    end

    # Recycles all supervised agents.
    def reset : Nil
      @group = WaitGroup.new
      @agents.each(&.agent.recycle)
    end
  end
end
