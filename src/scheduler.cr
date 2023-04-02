require "./mailbox"
require "./scheduler/cron"
require "./scheduler/every"

module Earl
  # FIXME: inherit from `DynamicSupervisor`
  #
  # TODO: schedule one time jobs
  class Scheduler < Supervisor
    # Wraps a scheduled Agent. Handles the times at which the agent must be
    # invoked, and the actual invocation.
    #
    # :nodoc:
    class JobRunner
      getter time : Time

      def initialize(@schedule : Schedulable, @agent : Earl::Mailbox(Time))
        @time = @schedule.next(Time.local)
      end

      def run(now : Time) : Nil
        reschedule(now)
        @agent.send(now)
      end

      private def reschedule(now)
        @time = @schedule.next(now > @time ? now : @time)
      end
    end

    # The actual agent that wakes up every minute to run all jobs that are
    # scheduled to run this minute, including those that should have run but
    # didn't because of time skips such as NTP adjustements or the computer
    # going to sleep or hibernation.
    #
    # OPTIMIZE: if the next job is scheduled to run in 5 minutes, we could sleep
    #           for 300 seconds, but... what if the clock is adjusted? it will
    #           all depend on the internal implementation of `sleep`: does it
    #           wait for 300s no matter what? or until now+300s is reached? or
    #           is it using a monotonic clock (hence suspending the process will
    #           delay the sleep for the duration of the suspend)?
    #
    # TODO: we could allow sub-minute resolution by sleeping until the next time
    #       a job has to run, clamped to the end of the minute, it's a best
    #       effort (there is no guarantee), but better than the 1 minute
    #       resolution of CRON jobs.
    #
    # :nodoc:
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

    # :nodoc:
    protected def initialize
      @jobs = [] of JobRunner
      super
      monitor(Runner.new)
    end

    # Schedules an `Agent` to be called at defined intervals.
    def add(agent : Earl::Mailbox(Time), schedule : Schedulable) : Nil
      log.info { "register agent=#{agent.class.name} schedule=#{schedule}" }
      @jobs << JobRunner.new(schedule, agent)
      monitor(agent)
    end

    # :nodoc:
    def each_job(& : JobRunner ->) : Nil
      @jobs.each { |job| yield job }
    end
  end

  @@scheduler = Scheduler.new

  Earl.application.monitor(@@scheduler)

  # Returns the Scheduler instance, started and monitored by `Earl.application`.
  def self.scheduler : Scheduler
    @@scheduler
  end

  # Schedules an `Agent` to be called at defined intervals. The `cron` argument
  # must be a valid `crontab(5)` string.
  #
  # The agent will be sent the scheduled time of invocation and must include
  # `Earl::Mailbox(Time)`.
  def self.schedule(agent : Earl::Mailbox(Time), *, cron : String) : Nil
    scheduler.add(agent, schedule: CRON.new(cron))
  end

  # Schedules an `Agent` to be called at defined intervals. The `every` argument
  # must be at least 1 minute (minimum resolution of the scheduler).
  #
  # The agent will be sent the scheduled time of invocation and must include
  # `Earl::Mailbox(Time)`.
  def self.schedule(agent : Earl::Mailbox(Time), *, every : Time::Span) : Nil
    scheduler.add(agent, schedule: Every.new(every))
  end

  # Schedules an agent to be spawned and run at the given time.
  # def self.schedule(agent : Agent, * in : Time::Span) : Nil
  # end

  # Schedules an agent to be spawned and run at the given time.
  # def self.schedule(agent : Agent, * at : Time) : Nil
  # end
end
