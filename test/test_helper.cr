require "minitest/autorun"
require "../src/earl"
require "syn/rw_lock"

class Minitest::Test
  @@rwlock = Syn::RWLock.new

  def setup
    @@rwlock.lock_read
  end

  def teardown
    @@rwlock.unlock_read
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
