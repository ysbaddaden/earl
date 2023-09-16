require "syn/core/mutex"
require "syn/core/condition_variable"
require "./errors"

module Earl
  # Earl::Queue is a Channel-like object with a simpler implementation, that
  # leverages Syn::Core structs, specifically targetted for Earl mailbox
  # requirements.
  #
  # It's obviously very limited compared to Channel(T). It doesn't support
  # `select`, only supports buffered queue (no sync channel with zero capacity),
  # but those features aren't needed by Earl mailboxes.

  # :nodoc:
  class Queue(M)
    property? close_on_stop : Bool = true
    property? closed : Bool = false

    def initialize(@backlog = 128)
      {% if M == Nil %}
        {% raise "Can't create an Earl::Mailbox(M) where M is Nil (or nilable)" %}
      {% elsif M.union? && M.union_types.any? { |m| m == Nil } %}
        {% raise "Can't create an Earl::Mailbox(M) where M is nilable" %}
      {% end %}

      @deque = Deque(M).new(@backlog)
      @mutex = Syn::Core::Mutex.new
      @readers = Syn::Core::ConditionVariable.new
      @writers = Syn::Core::ConditionVariable.new
    end

    def send(message : M) : Nil
      @mutex.synchronize do
        raise ClosedError.new if @closed

        until @deque.size < @backlog
          @writers.wait(pointerof(@mutex))
          raise ClosedError.new if @closed
        end

        @deque.push(message)
        @readers.signal
      end
    end

    @[AlwaysInline]
    def receive : M
      do_receive { raise ClosedError.new }
    end

    @[AlwaysInline]
    def receive? : M?
      do_receive { return nil }
    end

    private def do_receive(&) : M
      @mutex.synchronize do
        loop do
          if message = @deque.shift?
            @writers.signal
            return message
          end

          yield if @closed

          @readers.wait(pointerof(@mutex))
        end
      end
    end

    def empty? : Bool
      @mutex.synchronize { @deque.empty? }
    end

    # def lazy_empty? : Bool
    #   @deque.empty?
    # end

    def close : Nil
      return if @closed

      @mutex.synchronize do
        @closed = true
        @readers.broadcast
        @writers.broadcast
      end
    end

    # def reset : Nil
    #   @closed = false
    # end
  end
end
