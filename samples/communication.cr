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

foo = Foo.new
foo.spawn

bar = Bar.new(foo)
bar.spawn

5.times do |i|
  bar.send(i)
  Fiber.yield
end

foo.stop
bar.stop

until foo.stopped? && bar.stopped?
  sleep(0)
end
