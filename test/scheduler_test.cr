require "./test_helper"
require "../src/scheduler"

class Earl::SchedulerTest < Minitest::Test
  class Job
    include Earl::Artist(Time)

    getter called = Array(Time).new

    def call(time : Time) : Nil
      @called << time
    end
  end

  def setup
    EXCLUSIVE.lock_write
  end

  def teardown
    EXCLUSIVE.unlock_write
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
    job_1 = Job.new
    job_5 = Job.new
    job_17 = Job.new

    scheduler = Scheduler.new

    Timecop.scale(Time.local(2023, 4, 4, 22, 3, 27), 3600) do # 1 second == 1 hour
      scheduler.add(job_1, CRON.new("*/1 * * * *"))
      scheduler.add(job_5, Every.new(5.minutes))
      scheduler.add(job_17, Every.new(17.minutes))
      scheduler.spawn
      sleep(1.hours)
      scheduler.stop
    end

    refute_empty job_1.called
    refute_empty job_5.called
    refute_empty job_17.called

    # assert job_1 was called every minute
    job_1.called.map!(&.at_beginning_of_minute).reduce do |prev, curr|
      assert_equal 1.minute, curr - prev
      curr
    end

    # assert job_5 was called every 5 minutes
    job_5.called.map!(&.at_beginning_of_minute).reduce do |prev, curr|
      assert_equal 5.minutes, curr - prev
      curr
    end

    # assert job_17 was called every 17 minutes
    job_17.called.map!(&.at_beginning_of_minute).reduce do |prev, curr|
      assert_equal 17.minutes, curr - prev
      curr
    end
  end

  def test_runs_jobs_that_should_have_run_once_after_timeskip
    job_17 = Job.new

    scheduler = Scheduler.new

    Timecop.scale(Time.local(2023, 4, 4, 22, 3, 27), 1800) do # 1 second == 30 minutes
      scheduler.add(job_17, Every.new(17.minutes))
      scheduler.spawn
      sleep(7.5.minutes)

      Timecop.scale(40.minutes.from_now, 1800) do
        sleep(9.5.minutes)
      end

      scheduler.stop
    end

    assert_equal [
      Time.local(2023, 4, 4, 22, 5, 0),  # ran on time
      Time.local(2023, 4, 4, 22, 51, 0), # should have run sooner: runs immediately on wakeup
      Time.local(2023, 4, 4, 22, 56, 0), # continues to runs at the initially expected time
    ], job_17.called.map!(&.at_beginning_of_minute)
  end

  # def test_schedule_in
  #   skip "not implemented"
  # end

  # def test_schedule_at
  #   skip "not implemented"
  # end
end
