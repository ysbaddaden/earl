require "./mailbox"
require "./cron"

module Earl
  # A regular job runner.
  class Scheduler < Supervisor
    # Wraps a scheduled Agent. Handles the times at which the agent must be
    # invoked, and the actual invocation.
    #
    # nodoc
    class JobRunner
      getter time : Time

      def initialize(cron : String, @agent : Earl::Mailbox(Time))
        @cron = CRON.new(cron)
        @time = @cron.next(Time.local)
      end

      def run(now : Time) : Nil
        reschedule(now)
        @agent.send(now)
      end

      private def reschedule(now)
        @time = @cron.next(now > @time ? now : @time)
      end
    end

    # The actual agent that wakes up every minute to run all jobs that are
    # scheduled to run this minute, including those that should have run but
    # didn't because of time skips such as NTP adjustements or the computer
    # going to sleep or hibernation.
    #
    # nodoc
    class Runner
      include Agent

      def call : Nil
        loop do
          now = Time.local

          Earl.scheduler.each_job do |job|
            if job.time <= now
              job.run(now)
            end
          end

          sleep_until now.at_end_of_minute
        end
      end

      private def sleep_until(time : Time)
        seconds = time.to_unix - Time.local.to_unix
        sleep seconds.clamp(0..)
      end
    end

    # nodoc
    protected def initialize
      @jobs = [] of JobRunner
      super
      monitor(Runner.new)
    end

    # Schedules an Agent to be called at defined intervals. The `cron` argument
    # must be a valid `crontab(5)` string.
    def add(agent : Earl::Mailbox(Time), cron : String) : Nil
      log.info { "register agent=#{agent.class.name} cron=#{cron}" }
      @jobs << JobRunner.new(cron, agent)
      monitor(agent)
    end

    # nodoc
    def each_job(& : JobRunner ->) : Nil
      @jobs.each { |job| yield job }
    end
  end

  @@scheduler = Scheduler.new

  # Returns the Scheduler instance, started and monitored by `Earl.application`.
  def self.scheduler : Scheduler
    @@scheduler
  end

  Earl.application.monitor(@@scheduler)
end
