require "./test_helper"

private class Pending
  include Earl::Artist(Int32)

  def call(arg : Int32)
  end
end

private class Noop
  include Earl::Agent

  def initialize(@monkey = false)
  end

  def call
    return unless @monkey
    sleep 0
    raise "chaos"
  end
end

module Earl
  class SupervisorTest < Minitest::Test
    def test_starts_and_stops_monitored_agents
      agents = [Pending.new, Pending.new, Pending.new]
      supervisor = Supervisor.new

      agents.each { |agent| supervisor.monitor(agent) }
      assert supervisor.starting?
      assert agents.all?(&.starting?)

      supervisor.spawn
      assert supervisor.running?
      assert agents.all?(&.running?)

      supervisor.stop
      sleep 0
      assert supervisor.stopped?
      assert agents.all? { |a| a.stopped? || a.stopping? }
    end

    def test_normal_termination_of_supervised_agents
      agents = [Noop.new, Noop.new]
      supervisor = Supervisor.new

      agents.each { |agent| supervisor.monitor(agent) }
      assert supervisor.starting?
      assert agents.all?(&.starting?)

      supervisor.spawn
      sleep 0

      assert supervisor.stopped? || supervisor.stopping?
      assert agents.all? { |a| a.stopped? || a.stopping? }
    end

    def test_recycles_supervised_agents
      agent = Noop.new(monkey: true)
      supervisor = Supervisor.new

      supervisor.monitor(agent)
      assert supervisor.starting?
      assert agent.starting?

      supervisor.spawn
      sleep 0

      assert supervisor.running?
      10.times do
        refute agent.crashed?
        sleep 0
      end

      supervisor.stop
    end
  end
end
