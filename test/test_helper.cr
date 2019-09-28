require "minitest/autorun"
require "../src/earl"

class Minitest::Test
  protected def eventually(timeout : Time::Span = 5.seconds)
    start = Time.monotonic

    loop do
      sleep(0)

      begin
        yield
      rescue ex
        raise ex if (Time.monotonic - start) > timeout
      else
        break
      end
    end
  end
end

{% if flag?(:DEBUG) %}
  Earl::Logger.level = Earl::Logger::Severity::DEBUG
{% else %}
  Earl::Logger.level = Earl::Logger::Severity::SILENT
{% end %}

STDOUT.sync = true
Earl.application.spawn
