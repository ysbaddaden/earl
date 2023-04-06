require "minitest/autorun"
require "../src/earl"
require "syn/rw_lock"

EXCLUSIVE = Syn::RWLock.new

class Minitest::Test
  def setup
    EXCLUSIVE.lock_read
  end

  def teardown
    EXCLUSIVE.unlock_read
  end

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
