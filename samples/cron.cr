require "../src/earl"
require "../src/scheduler"

STDOUT.sync = true

class CalledEvery
  include Earl::Artist(Time)

  def initialize(@n : Int32)
  end

  def call(time : Time)
    log.info { "#{@n} minute·s (+#{(Time.local.nanosecond / 1000).round}us)" }
  end
end

Earl.schedule(CalledEvery.new(1), cron: "* * * * *")
Earl.schedule(CalledEvery.new(2), cron: "*/2 * * * *")
Earl.schedule(CalledEvery.new(5), cron: "*/5 * * * *")

Earl.application.start
