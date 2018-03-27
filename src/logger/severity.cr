module Earl
  module Logger
    enum Severity
      DEBUG
      INFO
      WARN
      ERROR
      SILENT

      def to_char : Char
        case self
        when DEBUG then 'D'
        when INFO then 'I'
        when WARN then 'W'
        when ERROR then 'E'
        when SILENT then 'S'
        else raise "unreachable"
        end
      end
    end
  end
end
