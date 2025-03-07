# Earl: API Specification

Earl agents are a set of modules that can be mixed into classes:

- [`Earl::Agent`](#earlagent)

  Core module, handles the agent's lifecycle (e.g.  started, stopped, crashed);

- [`Earl::Mailbox`](#earlmailbox)

  Extension module, adds a mailbox to an agent;

- [`Earl::Artist`](#earlartist)

  Agent module with a mailbox and automatic dispatch of received messages
  (actor-like).


Earl also provides ready to use agent classes:

- [`Earl.application`](#earlapplication)

  A specific [`Earl::Supervisor`](#earlsupervisor) suited for running programs.

- [`Earl::Supervisor`](#earlsupervisor)

  An agent that supervises other agents. It spawns agents in their own fiber and
  restarts them if they crash;

- [`Earl::Pool`](#earlpool)

  An agent that maintains a fixed-size pool of worker agents to dispatch work
  to. It spawns workers in their own fiber, and restarts them if they crash.


## Earl::Agent

The `Earl::Agent` module is the foundation module. It structures how the object
is started (`#start` or `#spawn`), stopped (`#stop`) and recycled (`#recycle`).
Each agent has an associated `Agent::State` accessible as `#state` that is
maintained throughout the agent's lifetime. It also provides hook methods,
invoked on certain state transitions (namely `#call`, `#terminate`, `#reset` and
`#trap`).


### Control-Flow & State

Control-flow will transition the state an agent is in. Agents always begin in
the 'starting' state. They transition to 'running' when they're started. They
may either transition to 'crashed' if an unhandled exception is raised, or to
'stopping' if they're asked to stop. They eventually transition into the
'stopped' state.

### Methods

Agents are regular classes. They can be initialized and have any kind of
methods. Including `Earl::Agent` and other extension modules injects different
methods for control-flow and communication, among other things.

- `#start(*, link = nil)`

  Starts an agent then blocks until the `#call` hook method returns, which means
  the agent is stopping or crashed —an exception was raised within `#call`.

  An agent can be linked using `#start(link: agent)`. The linked agent's `#trap`
  hook method will be invoked when the started agent stops or crashes. It will
  pass the agent object and the exception object if the agent crashed.
  [`Earl::Supervisor`](#earlsupervisor) and [`Earl::Pool`](#earlpool) rely on
  links and traps to supervise agents for example.

- `#spawn(*, link = nil)`

  Identical to `#start` but spawns a fiber to start the agent concurrently, and
  doesn't wait for `#call` to return.

- `#stop`

  Asks an agent to stop gracefully —it's impossible to forcefully stop an agent—
  by transitioning its state, then invokes the `#terminate` hook.

- `#recycle`

  Recycles a previously stopped or crashed agent, to return it back to its
  starting state. Agents meant to be recycled must implement the `#reset` hook
  to properly reinitialize the agent.


### Hooks

Hooks are regular methods, but are either abstract or have a noop
implementation. They're meant to react to an agent's lifecycle without
overriding control-flow methods, calling `super`, or causing conflicts. I.e.
hooks are always safe to override in agents.

- `#call`

  The main activity of an agent. It's called when the agent is started and
  should be running for as long as needed. It may run a single action or run a
  loop, and return to stop the agent normally. If the `#call` hook raises an
  exception or lets an unhandled exception bubble, the agent will crash.

  `#call` shouldn't rescue all exceptions but only the expected noise (e.g. a
  broken pipe). It should let the agent crash otherwise, to let linked agents
  (for example supervisors) do their job. For example log the error, then
  recycle and restart the agent.

  `#call` should try to terminate as soon as possible when the agent is asked to
  stop. It can stop gracefully, by finishing up processing buffered messages for
  examples, but must return. Some simple solutions are:

  - a `while running?; end` loop;
  - reacting to a closed mailbox with `while m = receive?; end`;
  - injecting regular `return unless running?` checks.

- `#terminate`

  Invoked when the agent is asked to stop, so you can do some cleanup, or close
  connections that will in turn cause `#call` to stop, for example.

  WARNING: it won't run within the agent's context, but within the caller
  context. This hook can be subject to concurrency issues!

- `#reset`

  Invoked when an agent is recycled. You must override the `#reset` hook if your
  agent is supposed to be restarted. Make sure to return the agent to its
  initial state, as if it had just been initialized.

  WARNING: it won't run within the agent's context, but the caller context. This
  hook can be subject to concurrency issues!

- `#trap(agent, exception = nil)`

  Invoked whenever a linked *agent* stopped (*exception* is `nil`) or crashed
  (*exception* is defined).

  WARNING: it won't run within the agent's context, but the caller context. This
  hook can be subject to concurrency issues!

### State methods

- `#state`

  The actual `Earl::Agent::State` object that maintains and transitions an
  object state. You should never interact with it directly, except maybe to case
  `state.value` against the `Earl::Agent::Status` enum.

The following methods are simple accessors that return `true` when the agent is
in that state. They return `false` otherwise:

- `#starting?`
- `#running?`
- `#stopping?`
- `#stopped?`
- `#crashed?`
- `#recycling?`

- `#log`

  An accessor for the agents' `Log` (one per class).

### Example

```ruby
class Counter
  include Earl::Agent

  def initialize(@original : Int32)
    @count = @original
  end

  def call
    while running?
      @count += 1
      sleep 1
    end
  end

  def reset
    @count = @original
  end
end

counter = Counter.new(123)

loop do
  counter.start
rescue
  counter.recycle
end
```


## Earl::Artist

The `Earl::Artist(M)` module is an [`Earl::Agent`](#earlagent). It includes
[`Earl::Mailbox(M)`](#earlmailbox). It also implements a `#call` hook to loop on
received messages, dispatched to the `#call(message)` methods that the artist
must implement.

The artist may have as many `#call(message)` overloads as needed. A single
overload or as many as the `M` union type defines for example.

Messages are currently received and dispatched in sequential order. There are no
guarantees this will always be the case. Artists may change someday to provide
message priority or asynchronous execution of messages.

To decide between an agent and an artist, if your object needs an incoming
mailbox, then you should always use an artist. You may use an agent if your
object doesn't need a mailbox, or needs an inter-process mailbox (e.g. AMQP
queue), or needs a particular control over the lifecycle of the agent, for
example.

### Example

```ruby
class Debugger
  include Earl::Artist(Int32 | String)

  def call(message : Int32)
    p [:integer, message]
  end

  def call(message : String)
    p [:string, message]
  end
end

counter = Counter.new

spawn do
  counter.send 1
  counter.send "hello"
  counter.stop
end

counter.start
# => [:number, 1]
# => [:string, "hello"]
```


## Agent Extensions

Developers writing extension modules shouldn't override hooks, but instead
override the control-flow methods, making sure to call `super`, so the hook
methods are left empty for developers to override without second thoughts or
inadvertently altering the control-flow, leaking resources, ...

Extension modules should follow the structure and design of existing agents and
extensions, to avoid introducing conflicting patterns (namings, hooks, methods).

### Earl::Mailbox

The `Earl::Mailbox(M)` module is an extension module. It should only be included
in classes that already include [`Earl::Agent`](#earlagent). The mailbox module
is generic and the type of messages the agent can receive (`M`) must be
specified.

Messages will be received by the agent in sequential order.

The mailbox will be closed when the agent stops, but will remain open if the
agent crashes. A linked agent may recycle and restart the agent, that will
consume the messages buffered in the mailbox. An agent running a loop can assume
`receive?` to return `nil` and exit the loop when that happens, without having
to check for `running?`.

- `#mailbox=`

  Direct accessor to swap the underlying `Channel(M)` object. The mailbox won't
  be closed anymore when the agent is stopped, since the mailbox is now
  considered to be shared.

  Despite having direct accessors to the mailbox, external agents aren't
  supposed to tinker with it, unless thay have very good reasons (see
  [`Earl::Pool`](#earlpool)).

- `#send(message)`

  Sends a *message* to the mailbox. This method is meant to be called from
  outside the agent, and is concurrency safe.

- `#receive`

  Blocks until a message is available in the mailbox, then returns the message.
  Raises an `Earl::ClosedError` exception if the mailbox is closed.

- `#receive?`

  Identical to `#receive` but returns `nil` instead of raising an exception if
  the mailbox is closed.

  Since the mailbox will be closed when the agent is asked to stop, and only
  then, an agent can have a `while m = receive?; end` loop in their `#call` hook
  to stop the agent when asked to.

```ruby
class Printer
  include Earl::Agent
  include Earl::Mailbox(Int32)

  def call
    while number = receive?
      p number
    end
  end
end

printer = Printer.new

spawn do
  printer.send(1)
  printer.send(2)
  printer.send(3)
  printer.stop
end

printer.start
# => 1
# => 2
# => 3
```

#### Example

```ruby
class Consumer
  include Earl::Artist(Int32)

  def call(number)
    p "#{self.class.name} received: #{number}"
  end
end

class Producer
  include Earl::Artist(Int32)

  def initialize
    @consumers = [] of Consumer
  end

  def register(consumer)
    @consumers.add(consumer)
  end

  def unregister(agent)
    @consumers.delete(agent)
  end

  def call(number)
    @consumers.each(&.send(number))
  end
end

producer = Producer.new

5.times do
  consumer = Consumer.new
  producer.register(consumer)
  consumer.spawn
end

Signal::INT.trap { producer.stop }
producer.start
```


## Provided Agents

The following objects are agent implementations with a generic role, which is to
start and monitor other agents. Being agents themselves they can be started,
spawned, stopped or recycled as needed.


### Earl.application

The `Earl.application` object is a [`Earl::Supervisor`](#earlsupervisor)
singleton suited for running programs. It traps some POSIX signals (e.g.
`SIGINT` and `SIGTERM`) and adds an `at_exit` handler to stop supervised agents.

Some agents can require `Earl.application` to be started. Libraries can also
assume it will be started and leverage it to have their agents monitored.

`Earl.application` can be spawned in the background then forgotten, but we
advise to leverage it as the main supervisor for your program.

Since `Earl.application` is a mere [`Earl::Supervisor`](#earlsupervisor) calling
`Earl.application.start` will spawn and monitor agents and block until the
program is told to stop.

### Earl::Supervisor

The `Earl::Supervisor` class is an agent that spawns then monitors previously
initialized agents. Supervisors can monitor any agent, as long as they include
[`Earl::Agent`](#earlagent). That is, supervisors can supervise other
supervisors.

Supervisors spawn each agent in their own fiber. They recycle and restart
crashed agents, but keeps them stopped if they normally returned. That is, until
the supervisor itself is asked to stop, or recycled/restarted, which will stop
or recycle/restart all supervised agents.

Since `Earl::Supervisor` recycles agents, the monitored agents must to implement
the `#reset` hook to return themselves into their starting state.

- `#monitor(agent)`

  Tells the supervisor to monitor an *agent*. Agents must be registered while
  the supervisor is still in its starting state. Raises an `ArgumentError`
  exception if the supervisor has already been started.

#### Example

```ruby
class Foo
  include Earl::Artist(Int32)

  def call(number)
  end
end

class Bar
  include Earl::Artist(Int32)

  def call(number)
  end
end

supervisor = Supervisor.new
supervisor.monitor(Foo.new)
supervisor.monitor
Bar.new

Signal::INT.trap { supervisor.stop }
supervisor.start
```

### Earl::Pool

The `Earl::Pool(A, M)` class is an artist that will initialize, start then
monitor a fixed-size pool of agents of type `A`. Workers must include
[`Earl::Agent`](#earlagent). Workers must also be capable to receive messages of
type `M`, that is include [`Earl::Mailbox(M)`](#earlmailbox) or be an
[`Earl::Artist(M)`](#earlartist) to receive jobs.

The pool starts each worker (`A` agents) in their own fiber. If a worker
crashes, it will be recycled and restarted. Workers aren't expected to stop by
themselves, unless the pool itself is stopping, which in turn asks all workers
to stop.

If a pool is itself supervised by an [`Earl::Supervisor`](#earlsupervisor)
agent, and the pool crashes, the supervisor will recycle and restart it, with
the original channel kept open. Pending messages will be dispatched once the
pool workers are restarted.

- `.new(capacity)`

  Initializes the pool to the given *capacity*.

- `#send(message)`

  Dispatches a *message* in a exactly-once manner to a single worker in the
  pool. Messages are dispatched sequentially but the processing by concurrent
  worker doesn't offer any guarantee over the actual execution order.

  Messages aren't saved and can't be acknowledged. If a worker crashes while
  processing a message, the message is lost.

  The pool's mailbox shall only be closed when the pool is stopped. Workers are
  expected to gracefully handle pending messages. Pending messages should never
  be lost because a worker crashed or the pool is going down, unless workers
  exit swiftly once their state changes and discard pending messages.

#### Example

```ruby
class Worker
  include Earl::Artist(Int32)

  def call(number)
    p "#{self} received #{number}"
  end
end

pool = Pool.new(capacity: 5)

spawn do
  100.times do |i|
    pool.send(i)
  end
  pool.stop
end

pool.start
```
