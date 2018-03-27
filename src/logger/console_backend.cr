require "./backend"

module Earl
  module Logger
    class ConsoleBackend < Backend
      property io : IO

      def initialize(@io = STDOUT)
      end

      def write(severity : Severity, agent : Agent, time : Time, message : String) : Nil
        io = @io
        io << severity.to_char
        io << " ["
        io << time
        io << " "
        io << Process.pid
        io << "] "
        io << agent.class.name
        io << " #"
        io << agent.object_id
        io << " "
        io.puts message
      end
    end
  end
end
