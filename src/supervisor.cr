require "mutex"
require "wait_group"
require "./agent"

module Earl
  # Supervise other agents.
  #
  # Use a `Supervisor` to monitor long lived agents that shall be spawned before
  # the program starts and are expected to stay alive for the whole duration of
  # the program, or at worst will stop by themselves after some time and won't
  # ever need to be restarted.
  #
  # The list of monitored agents is fixed and all agents must be added to the
  # supervisor before the supervisor starts.
  #
  # Each agent is spawned within its own dedicated `Fiber`. The supervisor takes
  # care to recycle and restart crashed agents. The supervisor automatically
  # shuts down when all its agents have stopped normally.
  #
  # ### Restart intensity
  #
  # To avoid an infinite loop when a monitored agent continuously crashes, a
  # supervisor defines a maximum restart intensity, that is a maximum number of
  # restart counts over a period of time. When the allowed intensity is reached,
  # then the
  #
  # For example with an +intensity+ of 1 and a +period+ of `5.seconds` then an
  # agent restarting twice within the last 5 seconds will cause the supervisor
  # to shutdown. The same agent crashing once within those 5 seconds or
  # repeatedly crashing every 6 seconds will always be restarted normally.
  class Supervisor
    include Agent

    # :nodoc:
    #
    # Wraps an agent to keep additional metadata such as the number of restart
    # and when they happened.
    class Supervised
      getter agent : Agent

      def initialize(@agent, intensity)
        @restarts = Deque(Time::Span).new(intensity)
      end

      def ==(other : Agent)
        @agent == other
      end

      # Returns true if we reached the maximum restart intensity (N restarts in
      # the last T seconds).
      def maximum_restarts?(intensity, period)
        # cleanup restarts that happened before the current period
        since = Time.monotonic - period
        while (time = @restarts.first?) && (time < since)
          @restarts.shift?
        end

        if @restarts.size < intensity
          @restarts << Time.monotonic
          false
        else
          true
        end
      end

      def recycle : Nil
        @restarts.clear
        @agent.recycle
      end
    end

    def initialize(@intensity : Int32 = 1, @period : Time::Span = 5.seconds)
      @agents = [] of Supervised
      @mutex = Mutex.new
      @group = WaitGroup.new
    end

    # Adds an agent to supervise. The agent will be started when the supervisor
    # is started.
    def monitor(agent : Agent) : Nil
      raise ArgumentError.new("agents must be monitored before starting the supervisor") unless starting?
      raise ArgumentError.new("can't monitor running agents") unless agent.starting?

      @mutex.synchronize do
        unless @agents.includes?(agent)
          @agents << Supervised.new(agent, @intensity)
          return
        end
      end
      raise ArgumentError.new("can't monitor the same agent twice")
    end

    # Spawns all agents to supervise in their dedicated `Fiber`.
    # Blocks until all agents have stopped.
    def call : Nil
      @mutex.synchronize do
        @agents.each { |supervised| spawn_agent(supervised.agent) }
      end
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

    # Recycles and restarts crashed agents. Takes note that an agent has stopped.
    def trap(agent : Agent, exception : Exception?) : Nil
      if exception
        agent.log.error(exception: exception) { "error" }
        log.error { "a supervised agent crashed (#{exception.class.name})" }

        if running?
          if try_restart?(agent)
            agent.recycle
          return
          end
        end
      end

      # the agent has terminated normally or the supervisor is shutting down
      @group.done
      sleep(0.seconds)
    end

    private def try_restart?(agent)
      supervised = @mutex.synchronize { @agents.find! { |s| s == agent } }
      return true unless supervised.maximum_restarts?(@intensity, @period)

      log.error { "a supervised agent reached the maximum restart intensity" }
      begin
        stop if running?
      rescue TransitionError
        # multiple supervised actors may fail in different threads and try to
        # stop the supervisor in parallel: silence any error (only one will
        # really stop the supervisor)
      end

      false
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
      @agents.each(&.recycle)
    end
  end
end
