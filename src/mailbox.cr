require "./agent"

module Earl
  # Extends an agent with a mailbox that receives messages of type `M`.
  #
  # NOTE: agents must use the `#receive : M` and `#receive? : M?` methods to
  # take messages from the mailbox —undocumented because they're `protected`.
  module Mailbox(M)
    macro included
      @mailbox_close_on_stop = true
    end

    # :nodoc:
    def mailbox : Channel(M)
      @mailbox ||= Channel(M).new(10)
    end

    # Replaces the mailbox. The mailbox won't be closed automatically when the
    # agent is asked to stop.
    def mailbox=(@mailbox : Channel(M)) : Channel(M)
      @mailbox_close_on_stop = false
      mailbox
    end

    # Send a message to the `Agent`. Raises if the mailbox is closed.
    def send(message : M) : Nil
      raise ClosedError.new if mailbox.closed?
      mailbox.send(message)
    end

    # Takes a previously received message. Raises if the mailbox is closed.
    protected def receive : M
      mailbox.receive? || raise ClosedError.new
    end

    # Takes a previously received message. Returns `nil` if the mailbox is closed.
    protected def receive? : M?
      mailbox.receive?
    end

    # :nodoc:
    def stop : Nil
      if @mailbox_close_on_stop
        mailbox.close
      end
      super
    end
  end
end
