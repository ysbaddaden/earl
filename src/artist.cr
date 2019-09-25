require "./agent"
require "./mailbox"

module Earl
  # An actor-like agent. It includes the following extension modules:
  # - `Agent`
  # - `Logger`
  # - `Mailbox(M)`
  #
  # Artists will automatically receive messages (of type `M`) and dispatch them
  # to the `#call(message)` method. `M` can be an union type and there can be as
  # many `#call(message)` method overloads to handle the different message
  # types.
  module Artist(M)
    macro included
      include Earl::Agent
      include Earl::Logger
      include Earl::Mailbox(M)
    end

    # Dispatches messages to `#call(message)` until asked to stop.
    def call
      while message = receive?
        call(message)
      end
    end

    abstract def call(message : M)
  end
end
