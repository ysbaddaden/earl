require "./agent"
require "./queue"

module Earl
  # Extends an agent with a mailbox that receives messages of type `M`.
  #
  # NOTE: agents must use the `#receive : M` and `#receive? : M?` methods to
  # take messages from the mailbox —undocumented because they're `protected`.
  module Mailbox(M)
    macro included
      @mailbox = Earl::Queue(M).new
    end

    # Replaces the mailbox. The mailbox won't be closed automatically when the
    # agent is asked to stop.
    def mailbox=(@mailbox : Queue(M)) : Queue(M)
      @mailbox.close_on_stop = false
      @mailbox
    end

    # Sends a message to this `Agent`. Raises `ClosedError` if the mailbox is closed.
    @[AlwaysInline]
    def send(message : M) : Nil
      @mailbox.send(message)
    end

    # Takes a previously received message. Raises `ClosedError` if the mailbox is closed.
    @[AlwaysInline]
    protected def receive : M
      @mailbox.receive
    end

    # Takes a previously received message. Returns `nil` if the mailbox is closed.
    @[AlwaysInline]
    protected def receive? : M?
      @mailbox.receive?
    end

    # :nodoc:
    def stop : Nil
      super
      @mailbox.close if @mailbox.close_on_stop?
    end

    # protected def reset_mailbox : Nil
    #   @mailbox = Queue(M).new(10)
    # end
  end
end
