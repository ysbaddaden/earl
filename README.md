# Earl

Actor objects for Crystal.

Crystal provides simple primitives for achieving concurrent applications, but no
advanced layer for structuring applications. Earl tries to fill that hole with a
as-simple-as possible API that's easy to grasp and understand.

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
require selected components, for example actors and mailboxes:

```crystal
require "earl/actor"
require "earl/mailbox"
```

For a formal depiction of the Earl library, you'll may want to keep reading the
*Rationale* section below. For a simpler introduction filled with examples, you
should skip down to the *Getting Started* section instead.


## Rationale

Earl actors are a set of modules that can be mixed into classes.

The `Earl::Actor` module is the foundation module. It structures how the object
will be started (`#start` or `#spawn`), stopped (`#stop`) and recycled
(`#recycle`). Each actor has an associated `Actor::State` accessible as `state`
that is maintained throughout the actor's lifetime, and a number of hook methods
that will be executed on certain state transitions (namely `#call`,
`#terminate`, `#reset` and `#trap`).

An actor must implement the `#call` method. This method is the actor's main
activity, and will be executed exactly once when the actor is started. An actor
may execute a single action then return, which will stop the actor, or run a
loop that must be exited when the actor's state changed, to properly stop it.

When the `#call` method returns the actor will be stopped properly, calling the
`#terminate` method hook that an actor may override to execute actions on
stop. If the `#call` method raises an exception, the actor will enter the
crashed state, and `#terminate` won't be called.

Actors shouldn't rescue all exceptions but only the expected noise (e.g. broken
pipe) and let the actor crash otherwise, allowing to bubble the crashed
information to other actors that can react on it, which is achieved by linking
two actors together.

Actors can be started with `#start` which will block until the actor stops.
Alternatively they may be started concurrently (in their own fiber) with
`#spawn` which will return immediately.

Actors can be linked to another actor when they're started, using the optional
`link` argument to `#start` (and `#spawn`). For example the actor A starts the
actor B and links itself to it, so whenever B stops or crashes, A's `#trap`
method will be called, passing the actor object and the exception if it crashed
(`nil` if it stopped). Supervisors and pools rely on links to restart the actors
they supervise for instance.

Actors can be asked to stop gracefully with `#stop`. Actors are responsible for
exiting swiftly when asked to stop, for example breaking out of a loop with
`while running?` or `while m = receive?` if the actor has a mailbox.

Eventually, a stopped or crashed actor may be recycled with `#recycle`. Actors
meant to be recycled must override the `#reset` method hook to return their
internal state to their initial values, as if they had just been initialized, so
a recycled object can be retarted any time.

---

Developers are encouraged to override the hook methods (`#call`, `#terminate`,
`#reset` and `#trap`) at will, but discouraged to override `Earl::Actor` methods
that control the actor state (`#start`, `#spawn`, `#stop` and `#recycle`),
unless they're writing extension modules, in which case they must override the
later methods, making sure to call `super`, so the hook methods are left empty
for developers to override without having to think about calling `super`.

Extension modules should follow the structure and design of existing actors and
extensions, to avoid introducing conflicting patterns (namings, hooks, methods).

---

The `Earl::Mailbox(M)` module is an extension module; it should only be included
in classes that already include `Earl::Actor`. The mailbox module is generic and
the type of messages the actor can receive, `M`, must be specified. Internally
it merely wraps a `Channel(M)` accessible as `#mailbox`, and delegates the
`#send`, `#receive` and `#receive?` on the actor itself to the channel.
Externally, the actor behaves just like it was itself a channel.

The mailbox will be closed when the actor stops, but will remain open if the
actor crashes. A linked actor (e.g. an `Earl::Supervisor`) may recycle and
restart an actor, and resume consuming buffered messages in the mailbox. An
actor running a loop may simple assume `receive?` to return `nil` and exit the
loop when that happens, without having to check for `running?`.

Despite having direct accessors to the mailbox, external actors are supposed to
behave properly and not tinker with it, except for very good reasons. For
example the mailbox may be swapped in place with `#mailbox=`; in that case the
channel won't be closed when the actor stops. For example `Earl::Pool` relies on
this to share a common channel across all its worker actors.

---

The `Earl::Registry(A, M)` module is an extension module; it should only be
included in classes that already include `Earl::Actor`. The registry module is
generic and both the type of actors to register, `A`, and messages to send them,
`M`, must be specified. Registered actors `A` must also be actors, thus include
`Earl::Actor`, but also `include `Earl::Mailbox(M)` so they can be sent the
expected messages. The module makes the registry object accessible as
`#registry` and delegates the `#register` and `#unregister` methods to it.

The registry maintains a list of registered actors. These actors may register or
unregister themselves at any time; the registry object is concurrency safe,
actors may register and unregister at any time, while messages are being sent.
The registry will be closed when the main actor stops; trying to register an
actor while the registry is closed will raise an `Earl::ClosedError` exception.

The producer actor, the one with the registry, may broadcast messages using
`#registry.send` to all previously registered actors in an exactly-once manner.
Newly registered actors will only receive messages sent *after* their
registration, and never receive messages previously broadcasted. If an exception
is raised while trying to send a message to a registered actor, that actor will
be unregistered —the likely reason being the actor's mailbox was closed.

---

The `Earl::Supervisor` class is an actor that starts then monitors previously
intialized actors. Supervisors may monitor any type of actor, as long as they
include `Earl::Actor`—so supervisors may supervise other supervisors.

Supervisors start each actor within their own fiber, recycling and restarting
the actor if they ever crashes, and keep them stopped if they stopped properly,
that is until the supervisor itself is recycled and restarted, that will
restart all supervised actors.

---

The `Earl::Pool(A, M)` class is an actor that will initialize, start then
monitor a fixed-size pool of actors of type `A` that must include `Earl::Actor`
as well as `Earl::Mailbox(M)` to receive expected messages.

The pool starts each worker (`A` actors) in its own fiber. If a worker crashes,
it will be recycled and restarted. Workers aren't expected to stop by
themselves, unless the pool itself is stopping, which in turn asked all workers
to stop.

The pool implements a single `#send` method that will dispatch the message to a
single worker in a exactly-once manner. Messages aren't saved and can't be
acknowledged; if a worker crashes while processing a message, the message will
be lost. Nevertheless, the pool's channel shall only be closed when the pool is
stopped, and workers are expected to gracefully handle pending messages. These
pending messages should never be lost because a worker crashed or the pool is
goind down, unless workers exit swiftly once their state changes and discard
pending messages.

If a pool is itself supervised by an `Earl::Supervisor` actor, and the pool
crashes, the supervisor will recycle and restart it, with the original channel
kept open, so pending messages will be processed once the pool workers are
started.


## Getting Started

### Actors

A simple actor is a class that includes `Earl::Actor` and implements a `#call`
method. For example:

```crystal
require "earl"

class Foo
  include Earl::Actor

  @count = 0

  def call
    while running?
      @count += 1
      sleep 1
    end
  end
end
```

Earl will then take care to monitor the actor's state, and provide a number of
facilities to start and stop actors, to trap an actor crash or normal stop, as
well as recycling.

Communication (`Earl::Mailbox`) and broadcasting (though `Earl::Registry`) are
opt-in extensions, and will be introduced below.

#### Start Actors

We may start this actor in the current fiber with `#start`, which will block
until the actor is stopped:

```crystal
foo = Foo.new
foo.start
```
Alternatively we could have called `#spawn` to start the actor in its own
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

#### Stop Actors

We can also ask an actor to gracefully stop with `#stop`. Each actor is
responsible for quickly returning from the `#call` method whenever the actor's
state change. Hence the `running?` call in the `Foo` actor above to break out of
the loop.

```crystal
foo.stop
```

Whenever an actor is stopped its `#terminate` method hook will be invoked,
allowing the actor to act upon termination (e.g. to notify other services,
closing connections, or overall cleanup required).

#### Link & Trap Actors

When starting (or spawning) an actor A we can link another actor B to be
notified when the actor A stopped or crashed (raised an unhandled exception).
The linked actor B must implement the `#trap(Actor, Exception?`) method. If
actor A crashed, then the unhandled exception will be passed, otherwise it will
be `nil`. In all cases, the stopped/crashed actor will be passed.

For example:
```crystal
require "earl"

class A
  include Earl::Actor

  def call
    # ...
  end
end

class B
  include Earl::Actor

  def call
    # ...
  end

  def trap(actor, exception = nil)
    if exception
      Earl.logger.error "#{actor} crashed with #{exception.message}"
    end
  end
end

a = A.new
b = B.new

a.start
b.start(link: a)
```

The `Earl::Supervisor` and `Earl::Pool` actors use links and traps to keep
services alive for example.

#### Recycle Actors

A stopped or crashed actor may be recycled in order to be restarted. Actors that
are meant to be recycled must implement the `#reset` method hook and return the
internal state of the actor to a fresh state, as if it had just been
initialized.

A recycled actor will see its state return back to the initial starting state,
allowing it to start. The `Earl::Supervisor`, for example, expects the actors it
monitors to properly reset themselves.


### Actor Extensions

#### Mailbox

The `Earl::Mailbox(M)` module will extend an actor with a Channel(M) of
messages and direct methods to `#send(M)` a message to an actor (concurrency
safe) and to receive them.

The module merely wraps a `Channel(M)` but proposes a standard structure for
actors to have an incoming mailbox of messages. All actors thus behave
identically, and we can assume that an actor that expects to receive messages
to have a `#send(M)` method.

Another advantage is that an actor's mailbox will be closed when the actor is
asked to terminate, so an actor can simply loop over `#receive?` until it
returns `nil`, without having to check for the actor's state.

See the *Registry* section below for an example.


#### Registry

The `Earl::Registry(A, M)` module will extend an actor to `#register` and
`#unregister` actors of type `A` that can receive messages of type `M`. The `A`
actors to register are expected to be capable to receive messages of type `M`,
that is to include `Earl::Mailbox(M)`. When running the actor can broadcast a
message to all registered actors. It may also ask all registered actors to stop.

For example we may declare a `Consumer` actor that will receive a count and
print it, until it's asked to stop:

```crystal
class Consumer
  include Earl::Actor
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
  include Earl::Actor
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

We can now create our producer and consumer actors, register the consumers to
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


### Specific Actors

#### Supervisor

The `Earl::Supervisor` actor monitors other actors (including other
supervisors). Monitored actors will be spawned in their own fiber when the
supervisor starts. If a monitored actor crashes it will be recycled then
restarted in its own fiber again.

A supervisor may be used to keep infinitely running concurrent actors. It may
also be used to prevent the main thread from exiting.

For example, using the `Producer` example from the *Registry* section, we may
supervise the producer actor with:

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

The `Earl::Pool(A, M)` actor starts and spawns a fixed size pool of actors of
type `A` to which we can dispatch messages (of type `M`) in a exactly-once way.
This is the opposite of `Earl::Registry` which broadcasts a message to all
registered actors, `Earl::Pool` will dispatch a message to a single worker,
which can be any worker in the pool.

Whenever a worker actor crashes, the pool will recycle and restart it. A worker
can stop properly, but should only do so when asked to.

Worker actors (of type `A`) are expected to be capable to be sent messages of
type `M`, that is to include `Earl::Mailbox(M)`, as well as to override their
`#reset` method to properly reset an actor.

Note that `Earl::Pool` will replace the workers' Mailbox, so they all share a
single `Channel(M)` to allow the exactly-once delivery of messages.

For example:

```crystal
class Worker
  include Earl::Actor
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

Pools are regular actors, so we could theoretically have pools of pools, but we
discourage such usage, since they'll mostly increase the complexity tree of your
application for little to no real benefit.

You may supervise pools with `Earl::Supervisor`, though pools are themselves
a supervisor of specific actors, so it may be redundant to supervise them too.


## Credits

- Author: Julien Portalier (@ysbaddaden)

Probably Inspired by my very limited knowledge of
[Celluloid](https://celluloid.io/) and Erlang OTP.


## License

Distributed under the Apache Software License 2.0. See LICENSE for details.
