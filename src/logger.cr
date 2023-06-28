require "./core_ext/log_dispatcher"
require "./logger/dispatcher"
require "./dynamic_supervisor"

module Earl
  # :nodoc:
  class LogSupervisor < DynamicSupervisor
    @pending : Array(Agent)? = [] of Agent

    def monitor(agent : Agent) : String?
      @mutex.synchronize do
        if pending = @pending
          raise ArgumentError.new("can't monitor the same agent twice") if pending.includes?(agent)

          pending << agent
          return
        end
      end

      super
    end

    def call : Nil
      pending = nil

      @mutex.synchronize do
        pending, @pending = @pending, nil
      end

      if pending
        pending.each { |agent| spawn_agent(agent) }
      end

      super
    end
  end

  @@log_supervisor = LogSupervisor.new
  Earl.application.monitor(@@log_supervisor)

  # :nodoc:
  def self.log_supervisor : LogSupervisor
    @@log_supervisor
  end
end
