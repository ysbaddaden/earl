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
      eventually { assert supervisor.running? }
      eventually { assert agents.all?(&.running?) }

      supervisor.stop
      eventually { assert supervisor.stopped? }
      eventually { assert agents.all? { |a| a.stopped? || a.stopping? } }
    end

    def test_normal_termination_of_supervised_agents
      agents = [Noop.new, Noop.new]
      supervisor = Supervisor.new

      agents.each { |agent| supervisor.monitor(agent) }
      assert supervisor.starting?
      assert agents.all?(&.starting?)

      supervisor.spawn

      eventually { assert supervisor.stopped? || supervisor.stopping? }
      eventually { assert agents.all? { |a| a.stopped? || a.stopping? } }
    end

    def test_recycles_supervised_agents
      agent = Noop.new(monkey: true)
      supervisor = Supervisor.new

      supervisor.monitor(agent)
      assert supervisor.starting?
      assert agent.starting?

      supervisor.spawn
      eventually { assert supervisor.running? }

      10.times do
        eventually { refute agent.crashed? }
      end

      supervisor.stop
    end
  end
end
