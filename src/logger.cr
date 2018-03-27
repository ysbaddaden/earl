require "./logger/actor"
require "./logger/console_backend"
require "./supervisor"

module Earl
  module Logger
    @@logger = Logger::Actor.new(Severity::INFO, ConsoleBackend.new(STDOUT))

    @@supervisor = Supervisor.new
    @@supervisor.monitor(@@logger)
    @@supervisor.spawn

    def self.level : Severity
      @@logger.level
    end

    def self.level=(severity : Severity) : Severity
      @@logger.level = severity
    end

    def self.backends : Array(Backend)
      @@logger.backends
    end

    def self.silent? : Bool
      @@logger.level == Severity::SILENT
    end

    {% for constant in Severity.constants %}
      {% method = constant.id.downcase %}

      {% unless constant == "SILENT".id %}
        def self.{{method}}? : Bool
          @@logger.{{method}}?
        end

        def self.{{method}}(agent : Agent, message : String) : Nil
          return unless @@logger.{{method}}?
          @@logger.send({Severity::{{constant.id}}, agent, Time.now, message})
        end

        def self.{{method}}(agent : Agent) : Nil
          return unless @@logger.{{method}}?
          @@logger.send({Severity::{{constant.id}}, agent, Time.now, yield})
        end
      {% end %}
    {% end %}

    struct Log
      def initialize(@agent : Agent)
      end

      {% for constant in Severity.constants %}
        {% method = constant.id.downcase %}

        def {{method}}? : Bool
          Logger.{{method}}?
        end

        {% unless constant == "SILENT".id %}
          def {{method}}(message : String) : Nil
            Logger.{{method}}(@agent, message)
          end

          def {{method}} : Nil
            Logger.{{method}}(@agent) { yield }
          end
        {% end %}
      {% end %}
    end

    def log : Log
      @log ||= Log.new(self)
    end
  end
end
