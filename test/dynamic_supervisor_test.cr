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
  class DynamicSupervisorTest < Minitest::Test
    def test_starts_and_stops_monitored_agents
      supervisor = spawn_supervisor

      agents = [Pending.new, Pending.new, Pending.new]
      agents.each { |agent| supervisor.monitor(agent) }
      eventually { assert agents.all?(&.running?) }

      supervisor.stop
      eventually { assert supervisor.stopped? }
      eventually { assert agents.all? { |a| a.stopped? || a.stopping? } }
      assert_empty supervisor.@agents
    end

    def test_normal_termination_of_supervised_agents
      supervisor = spawn_supervisor

      agents = [Noop.new, Noop.new]
      agents.each { |agent| supervisor.monitor(agent) }

      eventually { assert agents.all? { |a| a.stopped? || a.stopping? } }

      assert supervisor.running?
      assert_empty supervisor.@agents
    end

    def test_recycles_supervised_agents
      supervisor = spawn_supervisor

      agent = Noop.new(monkey: true)
      supervisor.monitor(agent)

      10.times do
        refute_empty supervisor.@agents
        eventually { refute agent.crashed? }
      end

      supervisor.stop
    end

    def test_cant_monitor_until_supervisor_is_started
      supervisor = DynamicSupervisor.new
      assert_raises(ArgumentError) { supervisor.monitor(Noop.new) }
    end

    def test_cant_monitor_running_agent
      supervisor = spawn_supervisor

      pending = Pending.new.tap(&.spawn)
      eventually { assert pending.running? }

      assert_raises(ArgumentError) { supervisor.monitor(pending) }
    end

    private def spawn_supervisor
      supervisor = DynamicSupervisor.new
      supervisor.spawn
      eventually { assert supervisor.running? }
      supervisor
    end
  end
end
