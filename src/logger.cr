require "logger"

module Earl
  @@logger = Logger.new(STDOUT)
  @@logger.level = Logger::DEBUG

  def self.logger
    @@logger
  end
end
