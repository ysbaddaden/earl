# Earl

Service objects for Crystal, aka Agents.

Crystal provides simple primitives for achieving concurrent applications, but no
advanced layer for structuring applications. Earl tries to fill that hole with a
as-simple-as possible object-based API that's easy to grasp and understand.

If your application has different, but interconnected, objects that should be
always alive, until they decide, or are asked, to stop; if these different
objects must communicate together; if you feel that you `spawn` and `loop` and
must `rescue` errors to log and restart objects all too often; if you need a
pool of workers to dispatch work to; if so, then Earl is for you.


## Status

Earl is still in its infancy, but should be faily useable already.

If you believe Earl could help structure your application(s) please try it
and report any shortcomings, bugs or successes you may have found!


## Usage

Add the `earl` shard to your dependencies then run `shards install`:

```yaml
dependencies:
  earl:
    github: ysbaddaden/earl
```

You can then `require "earl"` to pull everything. Alternatively, you may only
require selected components, for example agents and mailboxes:

```crystal
require "earl/agent"
require "earl/mailbox"
```

For a formal depiction of the Earl library, you'll may want to read <SPEC.md>.
For an informal introduction filled with examples, keep reading. For usage
examples see the <samples> directory.


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

Earl will then take care to monitor the agent's state, and provide a number of
facilities to start and stop agents, to trap an agent crash or normal stop, as
well as recycling.

Communication (`Earl::Mailbox`) and broadcasting (though `Earl::Registry`) are
opt-in extensions, and will be introduced below.

#### Start Agents

We may start this agent in the current fiber with `#start`, which will block
until the agent is stopped:

```crystal
foo = Foo.new
foo.start
```
Alternatively we could have called `#spawn` to start the agent in its own
fiber, and return immediately:

```crystal
foo = Foo.new
foo.spawn

do_something_else_concurrently
```

Depending on the context, it may be useful to block the current fiber, for
example if a library already spawned a dedicated fiber (e.g. `HTTP::Server`
requests); sometimes we need to start services in the background instead, and
continue on with something else.

#### Stop Agents

We can also ask an agent to gracefully stop with `#stop`. Each agent is
responsible for quickly returning from the `#call` method whenever the agent's
state change. Hence the `running?` call in the `Foo` agent above to break out of
the loop.

```crystal
foo.stop
```

Whenever an agent is stopped its `#terminate` method hook will be invoked,
allowing the agent to act upon termination (e.g. to notify other services,
closing connections, or overall cleanup required).

#### Link & Trap Agents

When starting (or spawning) an agent A we can link another agent B to be
notified when the agent A stopped or crashed (raised an unhandled exception).
The linked agent B must implement the `#trap(Agent, Exception?`) method. If
agent A crashed, then the unhandled exception will be passed, otherwise it will
be `nil`. In all cases, the stopped/crashed agent will be passed.

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
    if exception
      Earl.logger.error "#{agent} crashed with #{exception.message}"
    end
  end
end

a = A.new
b = B.new

a.start
b.start(link: a)
```

The `Earl::Supervisor` and `Earl::Pool` agents use links and traps to keep
services alive for example.

#### Recycle Agents

A stopped or crashed agent may be recycled in order to be restarted. Agents that
are meant to be recycled must implement the `#reset` method hook and return the
internal state of the agent to a fresh state, as if it had just been
initialized.

A recycled agent will see its state return back to the initial starting state,
allowing it to start. The `Earl::Supervisor`, for example, expects the agents it
monitors to properly reset themselves.


### Agent Extensions

#### Mailbox

The `Earl::Mailbox(M)` module will extend an agent with a Channel(M) of
messages and direct methods to `#send(M)` a message to an agent (concurrency
safe) and to receive them.

The module merely wraps a `Channel(M)` but proposes a standard structure for
agents to have an incoming mailbox of messages. All agents thus behave
identically, and we can assume that an agent that expects to receive messages
to have a `#send(M)` method.

Another advantage is that an agent's mailbox will be closed when the agent is
asked to terminate, so an agent can simply loop over `#receive?` until it
returns `nil`, without having to check for the agent's state.

See the *Registry* section below for an example.


#### Registry

The `Earl::Registry(A, M)` module will extend an agent to `#register` and
`#unregister` agents of type `A` that can receive messages of type `M`. The `A`
agents to register are expected to be capable to receive messages of type `M`,
that is to include `Earl::Mailbox(M)`. When running the agent can broadcast a
message to all registered agents. It may also ask all registered agents to stop.

For example we may declare a `Consumer` agent that will receive a count and
print it, until it's asked to stop:

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

Then we can declare a producer that will produce number and broadcast them to
the registered consumers:

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

We can now create our producer and consumer agents, register the consumers to
the producer and eventually spawn consumers (in their own fibers) and our
producer in the current fiber, thus blocking, until we hit Ctrl+C to interrupt
our program:

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

Despite registering consumers before starting the producer, the registry is
concurrency-safe and thus can be updated live at any time. This proves useful
when a consumer crashes and a new one must be registered against a running
producer.


### Specific Agents

#### Supervisor

The `Earl::Supervisor` agent monitors other agents (including other
supervisors). Monitored agents will be spawned in their own fiber when the
supervisor starts. If a monitored agent crashes it will be recycled then
restarted in its own fiber again.

A supervisor may be used to keep infinitely running concurrent agents. It may
also be used to prevent the main thread from exiting.

For example, using the `Producer` example from the *Registry* section, we may
supervise the producer agent with:

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

Now if the producer ever crashes, it will be restarted. You can test this by
adding a random `raise "chaos monkey"` into the `Producer#call` loop. The error
will be logged, the producer restarted and the application continue on.

#### Pool

The `Earl::Pool(A, M)` agent starts and spawns a fixed size pool of agents of
type `A` to which we can dispatch messages (of type `M`) in a exactly-once way.
This is the opposite of `Earl::Registry` which broadcasts a message to all
registered agents, `Earl::Pool` will dispatch a message to a single worker,
which can be any worker in the pool.

Whenever a worker agent crashes, the pool will recycle and restart it. A worker
can stop properly, but should only do so when asked to.

Worker agents (of type `A`) are expected to be capable to be sent messages of
type `M`, that is to include `Earl::Mailbox(M)`, as well as to override their
`#reset` method to properly reset an agent.

Note that `Earl::Pool` will replace the workers' Mailbox, so they all share a
single `Channel(M)` to allow the exactly-once delivery of messages.

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

Pools are regular agents, so we could theoretically have pools of pools, but we
discourage such usage, since they'll mostly increase the complexity of your
application for little to no real benefit.

You may supervise pools with `Earl::Supervisor`, though pools are themselves
a supervisor of specific agents, so it may be redundant to supervise them too.


## Credits

- Author: Julien Portalier (@ysbaddaden)

Probably Inspired by my very limited knowledge of
[Celluloid](https://celluloid.io/) and Erlang OTP.


## License

Distributed under the Apache Software License 2.0. See LICENSE for details.
