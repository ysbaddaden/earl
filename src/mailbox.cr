require "./agent"

module Earl
  module Mailbox(M)
    macro included
      @close_mailbox_on_close = true
    end

    def mailbox : Channel(M)
      @mailbox ||= Channel(M).new
    end

    def mailbox=(@mailbox : Channel(M))
      @close_mailbox_on_close = false
    end

    def send(message : M)
      mailbox.send(message)
    end

    protected def receive : M
      mailbox.receive? || raise ClosedError.new
    end

    protected def receive? : M?
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
