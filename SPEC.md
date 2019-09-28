# Earl: API Specification

Earl agents are a set of modules that can be mixed into classes:

- [`Earl::Agent`](#earlagent)

  Core module, handles the agent's lifecycle (e.g.  started, stopped, crashed);

- [`Earl::Logger`](#earllogger)

  Extension module, adds logging capabilities to an agent;

- [`Earl::Mailbox`](#earlmailbox)

  Extension module, adds a mailbox to an agent;

- [`Earl::Registry`](#earlregistry)

  A registry object to broadcast messages to other agents, stop them, and more;

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
[`Earl::Logger`](#earllogger) and [`Earl::Mailbox(M)`](#earlmailbox). It also
implements a `#call` hook to loop on received messages, dispatched to the
`#call(message)` methods that the artist must implement.

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

### Earl::Logger

The `Earl::Logger` module is both an Agent and an extension module.

The Agent must always be started (and supervised), usually by starting (or
spawning) `Earl.application`.

The agent handles the actual log of messages to backends. The module has class
methods to check whether a severity will be logged (e.g. `Earl::Logger.info?`),
and methods to log messages for an Agent (e.g. `.info(agent, message)` or
`.warn(agent) { message }`).

The extension module should only be included in classes that already include
[`Earl::Agent`](#earlagent). It provides a single method that wraps the Logger
class methods for the Agent (`e.g.` `log.info?` or `log.error { message }`).

Messages can be logged with a severity level. Messages greater or equal to this
level will be logged, messages below this severity level will be skipped. The
severity levels can be found in the `Earl::Logger::Severity` enum:

- `DEBUG`  —additional messages meant for debug purposes only;
- `INFO`   —normal information (default level);
- `WARN`   —report expected failures;
- `ERROR`  —report crashes and unexpected behavior;

One additional severity, `SILENT`, is available to disable the logger.

The module is configured with the following class methods:

- `.level=(severity)`

  Changes the minimal severity level. Defaults to `INFO`.

- `.backends`

  Accessor to an array of backends to write logged messages to. You can add or
  remove backends, but the array isn't concurrency safe. Backends should be
  configured before the application is started.

  The `Earl::Logger::ConsoleBackend` is available to write logs to any IO
  object. The console backend is enabled by default and writes to `STDOUT`.

  Custom backends can be created. They must extend the `Earl::Logger::Backend`
  class and implement the `#write(severity, agent, time, message)` abstract
  method.

The module adds the `#log` method to agents, which has three methods for each
severity. For example the `INFO` severity:

  - `#info?`

    Returns true if `INFO` messages are logged, that is if the configured
    severity level is `INFO` or lower (i.e. `VERBOSE` or `DEBUG`). Returns false
    otherwise.

  - `#info(message)`

    Logs message if the configured severity level is `INFO` or lower. Skips the
    message otherwise.

  - `#info { message }`

    Identical to `#info(message)` but delays the message evaluation. The block
    will only be evaluated if the configured level severity is `INFO` or lower.
    This method avoids allocating memory just to throw it away because `INFO`
    messages are skipped.

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

### Earl::Registry

The `Earl::Registry(A, M)` class keeps a list of agents. Its a generic and both
the type of agents to register, `A`, and messages to send them, `M`, must be
specified. Registered agents `A` must also be agents, thus include
[`Earl::Agent`](#earlagent), and must be capable to receive messages of type
`M`. I.e. include [`Earl::Mailbox(M)`](#earlmailbox) or be an
[`Earl::Artist(M)`](#earlartist).

The registry maintains a list of registered agents. The registry object is
concurrency safe. Agents can register and unregister at any time, while messages
are being broadcasted. That being said, the registry is optimized for infrequent
agent (un)registration but frequent iterations (e.g. frequently broadcasted
messages).

The registry should be stopped when the main agent stops. This will prevent any
further interaction with the registry: agents can't register, be iterated, and
messages can't be bent sent anymore.

The registry object has the following methods:

- `#register(agent)`

Registers an *agent*, so it will start receiving messages sent after its
registration. If the registry is being closed, trying to register an agent will
raise an `Earl::ClosedError` exception, preventing the agent to be registered.

- `#unregister(agent)`

Unregisters a previously registered *agent*, so it won't receive messages
anymore. Due to concurrency conditions, the agent may still receive a few
messages until the agent is indeed unregistered. If the registry is being
closed, then this is a noop.

- `#each(&block)`

Iterates previously registered agents.

- `#send(message)`

Broadcasts a *message* to all previously registered agents in an exactly-once
manner. If an agent registers itself while messages are being sent, it will only
receive later messages, the ones sent after it registered.

If the registry is closed, an `Earl::ClosedError` exception will be raised, and
the message won't be sent.

If delivering a message to a registered agent fails (i.e. an exception is
raised) the agent will be silently unregistered from the registry. The likely
reason is the agent's mailbox is closed.

- `#stop`

Asks all registered agents to stop by invoking their `#stop` method. If an agent
tries to register itself, then it will also be asked to stop, or an exception
will be raised.

If the registry is closed, an `Earl::ClosedError` exception will be raised, and
registered agents won't be stopped.

- `#closed?`

Returns `true` if the registry has been stopped.

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
    @registry = Earl::Registry(Consumer, Int32).new
  end

  def register(agent)
    @registry.register(agent)
  end

  def unregister(agent)
    @registry.unregister(agent)
  end

  def call(number)
    @registry.send(number)
  end

  def terminate
    @registry.stop
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

Some agents can require `Earl.application` to be started —for example
[`Earl::Logger`](#earllogger) does. Libraries can also assume it will be started
and leverage it to have their agents monitored.

`Earl.application` can be spawned in the background then forgotten, but we
advise to leverage it as the main supervisor for your program.

Since `Earl.application is a mere [`Earl::Supervisor`](#earlsupervisor) calling
`Earl.application.start` will spawn and monitor agents and block until the
program is told to stop.

### Earl::Supervisor

The `Earl::Supervisor` class is an agent that spawns then monitors previously
initialized agents. Supervisors can monitor any agent, as long as they include
[`Earl::Agent`](#earlagent). That is, supervisors can supervise other
supervisors.

Supervisors spawns each agent in their own fiber. They recycle and restart
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
