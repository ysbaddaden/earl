require "minitest/autorun"
require "../src/earl"
require "syn/rw_lock"
require "./support/timecop"

# use a specific local for time related tests to fail because of timezones
# (e.g. scheduler tests)
Time::Location.local = Time::Location.load("Europe/Paris")

# some tests can't run in parallel (e.g. timecop affects the global scope)
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
  Log.setup(:debug)
{% else %}
  Log.setup(:none)
{% end %}

STDOUT.sync = true
Earl.application.spawn
