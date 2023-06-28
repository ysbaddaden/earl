# :nodoc:
class Log
  module Dispatcher
    # :nodoc:
    def self.for(mode : DispatchMode) : self
      case mode
      in .sync?
        SyncDispatcher.new
      in .async?
        Earl::Logger::Dispatcher.new.tap do |dispatcher|
          Earl.log_supervisor.monitor(dispatcher)
        end
      in .direct?
        DirectDispatcher
      end
    end
  end
end
