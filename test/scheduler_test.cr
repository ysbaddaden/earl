require "./test_helper"
require "../src/scheduler"

class Earl::SchedulerTest < Minitest::Test
  class Job
    include Earl::Artist(Time)

    def call(time : Time) : Nil
    end
  end

  def test_add_cron
    scheduler = Scheduler.new
    scheduler.add(Job.new, schedule: CRON.new("*/5 * * * *"))
  end

  def test_add_every
    scheduler = Scheduler.new
    scheduler.add(Job.new, schedule: Every.new(5.minutes))
  end

  def test_runs_jobs
    skip "how to test?"
  end

  def test_runs_jobs_that_should_have_run_once_after_timeskip
    skip "how to test?"
  end

  # def test_schedule_in
  #   skip "not implemented"
  # end

  # def test_schedule_at
  #   skip "not implemented"
  # end
end
