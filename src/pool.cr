require "mutex"
require "wait_group"
require "./artist"

module Earl
  # Maintains a pool of worker agents of type `A` that will be spawned and
  # monitored.
  #
  # The pool will always be filled to its maximum capacity.
  #
  # ### Workers
  #
  # Crashed and unexpectedly stopped workers will be recycled and restarted,
  # until the pool is asked to stop.
  #
  # Worker agents can return as soon as possible when asked to stop, or keep
  # processing their mailbox until its empty.
  #
  # ### Mailbox
  #
  # Workers must include the `Mailbox(M)` module. Messages will be dispatched to
  # a single worker in an at-most-once manner.
  class Pool(A, M)
    include Artist(M)

    def initialize(@capacity : Int32)
      @workers = Array(A).new(@capacity)
      @mutex = Mutex.new(:unchecked)
      @group = WaitGroup.new(@capacity)
    end

    # Spawns workers in their dedicated `Fiber`. Blocks until all workers have
    # stopped.
    def call
      @capacity.times do
        ::spawn do
          agent = A.new
          @mutex.synchronize { @workers << agent }

          while agent.starting?
            log.info { "starting worker" }
            agent.mailbox = @mailbox
            agent.start(link: self)
          end
        end
      end

      @group.wait
    end

    def call(message : M)
      raise "unreachable"
    end

    # Recycles and restarts crashed and unexpectedly stopped agents.
    def trap(agent : A, exception : Exception?) : Nil
      if exception
        agent.log.error(exception: exception) { "error" }
        log.error { "worker crashed (#{exception.class.name})" }
      elsif agent.running?
        log.warn { "worker stopped unexpectedly" }
      end

      if running?
        return agent.recycle
      end

      @group.done
      @mutex.synchronize { @workers.delete(agent) }
    end

    # Asks each worker to stop.
    def terminate : Nil
      @workers.each do |agent|
        agent.stop rescue nil
      end
    end

    def recycle : Nil
      @workers.clear
      @group = WaitGroup.new(@capacity)
    end
  end
end
