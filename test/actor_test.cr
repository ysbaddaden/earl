require "./test_helper"

private class StatusActor
  include Earl::Actor

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
  include Earl::Actor

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
  class ActorTest < Minitest::Test
    def test_status
      actor = StatusActor.new
      assert_equal Actor::Status::Starting, actor.state.value
      assert actor.starting?

      spawn { actor.start }
      sleep(0)
      assert_equal Actor::Status::Running, actor.state.value
      assert actor.running?

      actor.stop
      assert_equal Actor::Status::Stopping, actor.state.value
      assert actor.stopping?

      sleep(0)
      assert_equal Actor::Status::Stopped, actor.state.value
      assert actor.stopped?
    end

    def test_start_executes_call
      actor = Noop.new
      refute actor.called

      actor.start
      assert actor.called
    end

    def test_start_eventually_executes_terminate
      actor = Noop.new
      actor.start
      assert_equal 1, actor.terminated
      assert actor.stopped?
    end

    def test_stop_executes_terminate
      actor = Noop.new
      actor.state.transition(Actor::Status::Running)
      actor.stop
      assert_equal 1, actor.terminated
    end

    def test_spawn
      actor = StatusActor.new

      actor.spawn
      refute actor.running?

      sleep(0)
      assert actor.running?
    end
  end
end
