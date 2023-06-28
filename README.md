# Earl

Service objects for Crystal, aka Agents.

Crystal provides primitives for achieving concurrent applications, but doesn't
have advanced layers for structuring applications. Earl tries to fill that gap
with a simple object-based API that's easy to grasp and understand.

## Is Earl for me?

- Your application has different, interconnected, objects that should always be
  alive, until they decide or are asked to stop.
- These different objects must communicate together.
- You feel that you `spawn` and `loop` and must `rescue` exceptions and restart
  objects too often.
-  You need a pool of workers to dispatch work to.
- ...

If so, then Earl is for you.


## Status

Earl is still in its infancy, but is fairly useable already.

If you believe Earl could help structure your application(s) please try it, and
report any shortcomings and successes you had!


## Usage

Add the `earl` shard to your dependencies then run `shards install`:

```yaml
dependencies:
  earl:
    github: ysbaddaden/earl
```

For a formal depiction of the Earl library, you can read <SPEC.md>. For an
informal introduction filled with examples, keep reading. For usage examples see
the <samples> directory.


## Getting Started

### Agents

A simple agent is a class that includes `Earl::Agent` and implements a `#call`
method. For example:

```crystal
require "earl"

class Foo
  include Earl::Agent

  @count = 0

  def call
    while running?
      @count += 1
      sleep 1
    end
  end
end
```

Earl monitors the agent's state, and provides facilities to start and stop
agents, to trap an agent crash or normal stop, as well as recycling them.

Communication (`Earl::Mailbox`) and broadcasting (`Earl::Registry`) are opt-in
extensions, and introduced below.

#### Start Agents

You can start this agent in the current fiber with `#start`. This will block
until the agent is stopped:

```crystal
foo = Foo.new
foo.start
```
Alternatively you can call `#spawn` to start the agent in its own fiber, and
return immediately:

```crystal
foo = Foo.new
foo.spawn

do_something_else_concurrently
```

Depending on the context, it can be useful to block the current fiber. A
library, for example, already spawned a dedicated fiber (e.g. `HTTP::Server`
connections). Sometimes we need to start services in the background instead, and
continue on.

#### Stop Agents

We can ask an agent to stop gracefully with `#stop`. Each agent must return
quickly from the `#call` method when the agent's state changes. Hence the
`running?` call in the `Foo` agent above to break out of the loop, for example.

```crystal
foo.stop
```

When an agent is stopped its `#terminate` method hook is called, allowing the
agent to act upon termination. For example notify other services, closing
connections, or cleaning up.

#### Link & Trap Agents

When starting or spawning an agent `A` we can link another agent `B` to be
notified when the agent `A` stopped or crashed (raised an unhandled exception).
The linked agent `B` must implement the `#trap(Agent, Exception?`) method. If
agent `A` crashed, then the unhandled exception is passed, otherwise it's `nil`.
In all cases, the stopped/crashed agent is passed.

For example:
```crystal
require "earl"

class A
  include Earl::Agent

  def call
    # ...
  end
end

class B
  include Earl::Agent

  def call
    # ...
  end

  def trap(agent, exception = nil)
    log.error("crashed with #{exception.message}") if exception
  end
end

a = A.new
b = B.new

a.start
b.start(link: a)
```

The `Earl::Supervisor` and `Earl::Pool` agents use links and traps to keep
services alive for instance.

#### Recycle Agents

A stopped or crashed agent can be recycled to be restarted. Agents meant to be
recycled must implement the `#reset` method, and return the agent's internal
state to its pristine condition. A recycled agent must be indistinguishable from
a created agent.

A recycled agent will return to the initial starting state, allowing it to
restart. `Earl::Supervisor`, for example, expects the agents it monitors to
properly reset themselves.


### Agent Extensions

#### Mailbox

The `Earl::Mailbox(M)` module extends an agent with a `Channel(M)` along with
methods to `#send(M)` a message to an agent and to receive them (concurrency
safe).

The module merely wraps a `Channel(M)` but proposes a standard structure for
agents to have an incoming mailbox of messages. All agents thus behave the
same, and we can assume that an agent that expects to receive messages has a
`#send(M)` method.

An agent's mailbox will be closed when the agent is asked to stop. An agent can
simply loop over `#receive?` until it returns `nil`, without having to check for
the agent's state.

See the *Registry* section below for an example.


#### Registry

The `Earl::Registry(A, M)` module will extend an agent to `#register` and
`#unregister` agents of type `A` that can receive messages of type `M`. The
agents to register must be capable to receive messages of type `M` —i.e. include
`Earl::Mailbox(M)` or `Earl::Artist(M)`). When running, the agent can broadcast
a message to all registered agents. It can also ask registered agents to stop.

For example, we can declare a `Consumer` agent that receives a count and prints
it, until it's asked to stop:

```crystal
class Consumer
  include Earl::Agent
  include Earl::Mailbox(Int32)

  def call
    while count = message.receive?
      p count
    end
  end
end
```

Now we can declare a producer that will broadcast numbers to registered
consumers:

```crystal
class Producer
  include Earl::Agent
  include Earl::Registry(Consumer, Int32)

  @count = 0

  def call
    while running?
      registry.send(@count += 1)
    end
  end

  def terminate
    registry.stop
  end
end
```

Now, we can create our producer and consumer agents, and register the consumers
to the producer. We spawn the consumers that will start in their dedicated
fiber. Last, we start the producer in the current fiber, that will block until
we hit `Ctrl+C` to interrupt the program:

```crystal
producer = Producer.new

a = Consumer.new
producer.register(a)
a.spawn

b = Consumer.new
producer.register(b)
b.spawn

Signal::INT.trap { producer.stop }
producer.start
```

The example registers consumers before starting the produce, but the registry
is concurrency-safe. Consumers can be added and removed at any time.


### Specific Agents

#### Supervisor

The `Earl::Supervisor` agent monitors other agents (including other
supervisors). Monitored agents are spawned in their own fiber when the
supervisor starts. If a monitored agent crashes it's recycled then restarted
in its own fiber.

A supervisor can keep indefinitely running concurrent agents. It can also
prevent the main thread from exiting.

For example, let's supervise the `Producer` example from the *Registry* section:

```crystal
supervisor = Supervisor.new

producer = Producer.new
supervisor.monitor(producer)

a = Consumer.new
producer.register(a)
a.spawn

b = Consumer.new
producer.register(b)
b.spawn

Signal::INT.trap { supervisor.stop }
supervisor.start
```

Now if the producer crashes, it will be restarted. You can test this by adding a
random `raise "chaos monkey"` into the `Producer#call` loop. The error will be
logged, the producer restarted and the application continue running.

#### Pool

The `Earl::Pool(A, M)` agent spawns a fixed size list of agents of type `A`, to
which we can dispatch messages (of type `M`). Messages are delivered to a single
worker of the pool in an exactly-once manner. This is different from
`Earl::Registry` that broadcasts a message to all registered agents.

Whenever a worker agent crashes, the pool will recycle and restart it. A worker
can stop normally, but it should only do so when asked to stop.

Worker agents (of type `A`) must be capable to receive messages of type `M`.
I.e. they include `Earl::Mailbox(M)` or `Earl::Artist(M)`. They must also
override their `#reset` method to properly reset an agent.

Note that `Earl::Pool` will replace the workers' mailbox. All workers then share
a single `Channel(M)` for an exactly-once delivery of messages.

For example:

```crystal
class Worker
  include Earl::Agent
  include Earl::Mailbox(String)

  def call
    while message = receive?
      p message
    end
  end
end

pool = Earl::Pool(Worker, String).new(capacity: 10)

spawn do
  5.times do |i|
    pool.send("message #{i}")
  end
  pool.stop
end

pool.start
# => message 1
# => message 2
# => message 3
# => message 4
# => message 5
```

Pools are regular agents, so we can have pools of pools, but we discourage such
usage. It'll only increase the complexity of your application for little or no
real benefit.

You can supervise pools with `Earl::Supervisor`. It can feel redundant because
pools already monitor other agents, but it can be useful to only have a few
supervisors to start (and stop).


## Credits

- Author: Julien Portalier (@ysbaddaden)

Somewhat inspired by my very limited knowledge of Erlang OTP & Elixir.


## License

Distributed under the Apache Software License 2.0. See LICENSE for details.
