require "./backend"

module Earl
  module Logger
    class ConsoleBackend < Backend
      property io : IO

      def initialize(@io = STDOUT)
      end

      def write(severity : Severity, agent : Agent, time : Time, message : String) : Nil
        @io << "#{severity.to_char} [#{time} #{Process.pid}] #{agent.class.name} #{message}\n"
      end
    end
  end
end
