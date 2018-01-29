module Earl
  # Extends an `Actor` with a mailbox so it can be sent messages and receive
  # them.
  #
  # The mailbox module is a mere wrapper for `Channel(M)`, and all its value
  # comes from proposing a standard interface for actor communication. One
  # advantage, though, is that an actor may simply loop over `receive?` and
  # break out whenever it returns `nil` instead of reacting upong the actor's
  # status.
  #
  # The mailbox will be automatically closed when the actor is stopped (unless
  # the mailbox has been replaced, see `#mailbox=`), but won't be if the actor
  # crashed, which means a recycled then restarted actor won't have lost any
  # message, and will resume just like it never failed; well, except for the
  # message that crashed the actor in the first place, that one is lost. This
  # behavior is automatic if the actor is supervised by a `Supervisor` or a
  # `Pool`.
  module Mailbox(M)
    macro included
      @close_mailbox_on_close = true
    end

    # Direct access to the `Channel` behind the mailbox. This should be avoided,
    # but can be useful in situations where an actor has many different channels
    # to listen on in a `select` statement for example.
    def mailbox : Channel(M)
      @mailbox ||= Channel(M).new
    end

    # Replaces this actor's mailbox with another one. This should be avoided,
    # but may be useful in situations where we want to dispatch a message
    # at-most-once or exactly-once to a group of concurrent actors. This is used
    # by `Pool` for example.
    #
    # Replacing the defaut mailbox will prevent the mailbox from being closed
    # when the actor is stopped.
    def mailbox=(@mailbox : Channel(M))
      @close_mailbox_on_close = false
    end

    # Send a message of type `M` to the `Actor`.
    def send(message : M) : Nil
      mailbox.send(message)
    end

    # Returns a previously received message. Blocks if the mailbox is empty
    # until a message is sent, and raises a `Channel::ClosedError` when the
    # actor is closed while waiting.
    #
    # NOTE: this method must be considered `protected` but marking it as such
    # would prevent the method from being documented.
    def receive : M
      mailbox.receive
    end

    # Same as `receive` but returns `nil` instead of raising when the actor is
    # stopped while waiting.
    #
    # NOTE: this method must be considered `protected` but marking it as such
    # would prevent the method from being documented.
    def receive? : M?
      mailbox.receive?
    end

    # :nodoc:
    def stop
      if @close_mailbox_on_close
        mailbox.close
      end
      super
    end
  end
end
