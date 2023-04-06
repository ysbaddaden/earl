require "./schedulable"

module Earl
  struct Every
    include Schedulable

    def initialize(@every : Time::Span, @since : Time = Time.unix(0))
      if @every < 1.minute
        raise ArgumentError.new("Every #{@every} is too short, it must be at least 1 minute")
      end
    end

    def next(t : Time = Time.local) : Time
      occurrences = ((t - @since) / @every).floor
      @since + @every * (occurrences + 1)
    end
  end
end
