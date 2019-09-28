require "../src/earl"

class Foo
  include Earl::Artist(Int32 | String)

  def call(message : String)
    log.info [:string, message].inspect
  end

  def call(message : Int32)
    log.info { [:number, message].inspect }
  end
end

class Bar
  include Earl::Artist(Int32)

  def initialize(@foo : Foo)
  end

  def call(number : Int32)
    if number.odd?
      @foo.send(number)
    else
      @foo.send(number.to_s)
    end
  end
end

# create agents:
foo = Foo.new
Earl.application.monitor(foo)

bar = Bar.new(foo)
Earl.application.monitor(bar)

# spawn all agents (supervisor, logger, foo & bar):
Earl.application.spawn

# send some messages:
1.upto(5) { |i| bar.send(i) }

# let agents run:
sleep(10.milliseconds)

# stop everything:
Earl.application.stop
