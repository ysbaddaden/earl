require "./supervisor"

module Earl
  class Application < Supervisor
    protected def initialize
      @atomic = Atomic(Int32).new(0)

      super
    end

    def signals
      @signals ||= [
        Signal::INT,
        Signal::TERM,
      ]
    end

    def call
      _, success = @atomic.compare_and_set(0, 1)
      if success
        signals.each do |signal|
          signal.trap do
            log.debug "received SIG#{signal} signal"
            Fiber.yield
            exit
          end
        end

        at_exit do
          stop if running?
        end
      end

      super
    end
  end

  @@application = Application.new

  def self.application
    @@application
  end
end
