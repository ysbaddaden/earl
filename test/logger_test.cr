require "./test_helper"

private class Noop
  include Earl::Agent

  def call
  end
end

private class Loggy
  include Earl::Agent
  include Earl::Logger

  def call
  end
end

module Earl
  module Logger
    def self.pending_messages?
      !@@logger.@mailbox.@queue.not_nil!.empty?
    end
  end

  class LoggerTest < Minitest::Test
    def setup
      EXCLUSIVE.lock_write
      wait_for_logger
    end

    def teardown
      wait_for_logger
    ensure
      EXCLUSIVE.unlock_write
    end

    def test_level
      with_level Logger::Severity::DEBUG do
        assert Logger.debug?
        assert Logger.info?
        assert Logger.warn?
        assert Logger.error?
        refute Logger.silent?
      end

      with_level Logger::Severity::SILENT do
        refute Logger.debug?
        refute Logger.info?
        refute Logger.warn?
        refute Logger.error?
        assert Logger.silent?
      end

      with_level Logger::Severity::WARN do
        refute Logger.debug?
        refute Logger.info?
        assert Logger.warn?
        assert Logger.error?
        refute Logger.silent?
      end
    end

    def test_log_methods
      noop = Noop.new
      loggy = Loggy.new

      with_level Logger::Severity::INFO do
        refute loggy.log.debug?
        assert loggy.log.info?
        assert loggy.log.warn?
        assert loggy.log.error?
        refute loggy.log.silent?

        log, _ = capture do
          Logger.debug(noop, "debug message")
          Logger.info(noop) { "informational message" }
          loggy.log.warn { "warning message" }
          loggy.log.error("error message")
          wait_for_logger
        end

        refute_match /D \[.+\] Noop debug message/, log
        assert_match /I \[.+\] Noop informational message/, log
        assert_match /W \[.+\] Loggy warning message/, log
        assert_match /E \[.+\] Loggy error message/, log
      end

      with_level Logger::Severity::SILENT do
        refute loggy.log.debug?
        refute loggy.log.info?
        refute loggy.log.warn?
        refute loggy.log.error?
        assert loggy.log.silent?

        log, _ = capture do
          loggy.log.debug { "debug message" }
          Logger.info(noop) { "informational message" }
          Logger.warn(noop, "warning message")
          loggy.log.error("error message")
        end

        refute_match /D \[.+\] Loggy debug message/, log
        refute_match /I \[.+\] Noop informational message/, log
        refute_match /W \[.+\] Loggy warning message/, log
        refute_match /E \[.+\] Loggy error message/, log
      end

      with_level Logger::Severity::ERROR do
        refute loggy.log.debug?
        refute loggy.log.info?
        refute loggy.log.warn?
        assert loggy.log.error?
        refute loggy.log.silent?

        log, _ = capture do
          loggy.log.debug("debug message")
          Logger.info(noop, "informational message")
          loggy.log.warn { "warning message" }
          Logger.error(noop) { "error message" }
        end

        refute_match /D \[.+\] Loggy debug message/, log
        refute_match /I \[.+\] Noop informational message/, log
        refute_match /W \[.+\] Loggy warning message/, log
        assert_match /E \[.+\] Noop error message/, log
      end
    end

    private def with_level(severity : Logger::Severity)
      original = Logger.level
      begin
        Logger.level = severity
        yield
      ensure
        Logger.level = original
      end
    end

    private def capture
      capture_io do
        yield
        wait_for_logger
        sleep 10.milliseconds
      end
    end

    private def wait_for_logger
      eventually(2.seconds) do
        refute Logger.pending_messages?, "expected logger queue to eventually be empty"
      end
    end
  end
end
