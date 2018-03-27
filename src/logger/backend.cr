module Earl
  module Logger
    abstract class Backend
      abstract def write(severity : Severity, agent : Agent, time : Time, message : String) : Nil
    end
  end
end
