require "minitest/autorun"
require "../src/earl"
require "./support/rwlock"
require "./support/timecop"

# use a specific local for time related tests to fail because of timezones
# (e.g. scheduler tests)
Time::Location.local = Time::Location.load("Europe/Paris")

# some tests can't run in parallel (e.g. timecop affects the global scope)
EXCLUSIVE = Earl::RWLock.new

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
      sleep(0.seconds)

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

Log.setup_from_env(default_level: :none)
STDOUT.sync = true

Earl.application.spawn
