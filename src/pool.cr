require "mutex"
require "./artist"

module Earl
  class Pool(A, M)
    include Artist(M)

    def initialize(@capacity : Int32)
      @workers = Array(A).new(@capacity)
      @mutex = Mutex.new
      @fiber = nil
    end

    def call : Nil
      @capacity.times do
        spawn do
          agent = A.new
          @mutex.synchronize { @workers << agent }

          while agent.starting?
            log.info { "starting worker ##{agent.object_id}" }
            agent.mailbox = mailbox
            agent.start(link: self)
          end
        end
      end

      @fiber = Fiber.current
      Scheduler.reschedule

      until @workers.empty?
        Fiber.yield
      end
    end

    def trap(agent : A, exception : Exception?) : Nil
      if exception
        log.error { "worker ##{agent.object_id} crashed message=#{exception.message} (#{exception.class.name})" }
      elsif agent.running?
        log.warn { "worker ##{agent.object_id} stopped unexpectedly" }
      end

      if running?
        return agent.recycle
      end

      @mutex.synchronize { @workers.delete(agent) }
    end

    def terminate : Nil
      @workers.each do |agent|
        agent.stop rescue nil
      end

      if fiber = @fiber
        @fiber = nil
        Scheduler.enqueue(fiber)
      end
    end
  end
end
