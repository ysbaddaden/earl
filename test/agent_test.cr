require "./test_helper"

private class StatusAgent
  include Earl::Agent

  getter called = false
  getter terminated = false

  def call
    @called = true

    while running?
      sleep(0)
    end
  end

  def terminate
    @terminated = true
  end
end

private class Noop
  include Earl::Agent

  getter called = false
  getter terminated = 0

  def call
    @called = true
  end

  def terminate
    @terminated += 1
  end
end

module Earl
  class AgentTest < Minitest::Test
    def test_status
      agent = StatusAgent.new
      assert agent.starting?

      spawn { agent.start }
      eventually { assert agent.running? }

      agent.stop
      assert agent.stopping?

      eventually { assert agent.stopped? }
    end

    def test_start_executes_call
      agent = Noop.new
      refute agent.called

      agent.start
      assert agent.called
    end

    def test_start_eventually_executes_terminate
      agent = Noop.new
      agent.start
      assert_equal 1, agent.terminated
      assert agent.stopped?
    end

    def test_stop_executes_terminate
      agent = Noop.new
      agent.@state.transition(agent, Agent::Status::Running)
      agent.stop
      assert_equal 1, agent.terminated
    end

    def test_spawn
      agent = StatusAgent.new

      agent.spawn(_yield: false)
      refute agent.running?

      eventually { assert agent.running? }
    end
  end
end
