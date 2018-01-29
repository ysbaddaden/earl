module Earl
  class Error < Exception
  end

  # Raised whenever an actor's state can't be transitioned to a new state, thus
  # breaking the finite state machine rules. For example trying to transition
  # from `starting` to `stopping` isn't possible.
  class TransitionError < Exception
  end

  class ClosedError < Exception
  end
end
