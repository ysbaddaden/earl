require "./logger/actor"
require "./logger/console_backend"
require "./application"

module Earl
  # Requires `Earl.application` to be started. Otherwise logged messages will
  # hang the current program when the logger mailbox is full!
  #
  # ### Extension module:
  #
  # Include in agents to add a single `#log` method to access `Log` methods for
  # the current agent. The methods eventually delegate to `Logger` class methods.
  #
  # ### Configuration:
  #
  # - `#level=` —change the `Severity` level (default: `Severity::INFO`).
  # - `#backends` —add or remove backends (default: `ConsoleBackend`).
  #
  # The configuration may be changed at any time, but we advise to configure
  # once before starting `Earl.application`.
  #
  # ### Custom backends:
  #
  # Custom backends must inherit from `Backend` and implement the
  # `Backend#write` abstract method.
  module Logger
    @@logger = Logger::Actor.new(Severity::INFO, ConsoleBackend.new)
    Earl.application.monitor(@@logger)

    def self.level : Severity
      @@logger.level
    end

    # Configures the severity level. Can be changed at any time.
    def self.level=(severity : Severity) : Severity
      @@logger.level = severity
    end

    # The list of currently enabled backends. Can be modified to add, remove or
    # configure backends, but must be done before starting `Earl.application`.
    #
    # Custom backends must inherit from `Backend`.
    def self.backends : Array(Backend)
      @@logger.backends
    end

    # Returns true if the current level is SILENT.
    def self.silent? : Bool
      @@logger.level == Severity::SILENT
    end

    {% for constant in Severity.constants %}
      {% method = constant.id.downcase %}

      {% unless constant == "SILENT".id %}
        # Returns true if the current level is {{constant.id}} or lower.
        def self.{{method}}? : Bool
          @@logger.{{method}}?
        end

        # Logs *message* if `{{method}}?` returns true.
        def self.{{method}}(agent : Agent, message : String) : Nil
          return unless @@logger.{{method}}?
          @@logger.send({Severity::{{constant.id}}, agent, Time.now, message})
        end

        # Logs the message returned by the block if `{{method}}?` returns
        # true, otherwise the block is never invoked.
        def self.{{method}}(agent : Agent, &block : -> String) : Nil
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
      # :nodoc:
      def initialize(@agent : Agent)
      end

      # Returns true if the current level is SILENT.
      def silent? : Bool
        Logger.silent?
      end

      {% for constant in Severity.constants %}
        {% unless constant == "SILENT".id %}
          {% method = constant.id.downcase %}

          # Returns true if the current level is {{constant.id}} or lower.
          def {{method}}? : Bool
            Logger.{{method}}?
          end

          # Logs *message* if `{{method}}?` returns true.
          def {{method}}(message : String) : Nil
            Logger.{{method}}(@agent, message)
          end

          # Logs the message returned by the block if `{{method}}?` returns
          # true, otherwise the block is never invoked.
          def {{method}}(&block : -> String) : Nil
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
