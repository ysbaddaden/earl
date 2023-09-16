# :nodoc:
class Log
  module Dispatcher
    # :nodoc:
    def self.for(mode : DispatchMode) : self
      case mode
      in .sync?
        SyncDispatcher.new
      in .async?
        dispatcher = Earl::Logger::AsyncDispatcher.new
        dispatcher.spawn(link: Earl::Logger.monitor)
        dispatcher
      in .direct?
        DirectDispatcher
      end
    end
  end
end
