require "timecop"

module Timecop
  class TimeStackItem
    def scale_sleep(duration : Time::Span) : Time::Span
      if @mock_type.scale?
        duration / @scaling_factor
      else
        duration
      end
    end
  end
end

def sleep(duration : Number) : Nil
  sleep(duration.seconds)
end

def sleep(duration : Time::Span) : Nil
  if Timecop.frozen?
    previous_def(Timecop.top_stack_item.scale_sleep(duration))
  else
    previous_def
  end
end
