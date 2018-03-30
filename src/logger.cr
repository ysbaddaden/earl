require "./logger/actor"
require "./logger/console_backend"
require "./application"

module Earl
  module Logger
    @@logger = Logger::Actor.new(Severity::INFO, ConsoleBackend.new(STDOUT))
    Earl.application.monitor(@@logger)

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

    def self.error(agent : Agent, ex : Exception)
      error(agent) do
        String.build do |str|
          str << ex.class.name
          str << ": "
          str << ex.message
          str << " at "
          str.puts ex.backtrace.first?
          ex.backtrace.each do |line|
            str << "  "
            str.puts line
          end
        end
      end
    end

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

      def error(ex : Exception)
        Logger.error(@agent, ex)
      end
    end

    def log : Log
      @log ||= Log.new(self)
    end
  end
end
