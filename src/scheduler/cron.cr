require "./schedulable"

module Earl
  # Parse CRON definitions and reports when the next CRON is expected to run.
  struct CRON
    include Schedulable

    class ParseError < Exception
    end

    # :nodoc:
    EXTENSIONS = {
      "@yearly"   => "0 0 1 1 *",
      "@annually" => "0 0 1 1 *",
      "@monthly"  => "0 0 1 * *",
      "@weekly"   => "0 0 * * 0",
      "@daily"    => "0 0 * * *",
      "@hourly"   => "0 * * * *",
    }

    # :nodoc:
    MONTHS = {
      "jan" => 1,
      "feb" => 2,
      "mar" => 3,
      "apr" => 4,
      "may" => 5,
      "jun" => 6,
      "jul" => 7,
      "aug" => 8,
      "sep" => 9,
      "oct" => 10,
      "nov" => 11,
      "dec" => 12,
    }

    # :nodoc:
    DAYS = {
      "mon" => 1,
      "tue" => 2,
      "wed" => 3,
      "thu" => 4,
      "fri" => 5,
      "sat" => 6,
      "sun" => 7,
    }

    @cron : String
    @minutes : Array(Int32)
    @hours : Array(Int32)
    @days_of_month : Array(Int32)
    @months : Array(Int32)
    @days_of_week : Array(Int32)

    def initialize(cron : String)
      if cron.starts_with?('@')
        cron = EXTENSIONS.fetch(cron) { raise ParseError.new("unknown extension #{cron}") }
      end

      elements = cron.split(' ', 5, remove_empty: true)
      unless elements.size == 5
        raise ParseError.new("invalid cron '#{cron}' expected 5 elements but got #{elements.size}")
      end

      minute, hour, day_of_month, month, day_of_week = elements

      @cron = cron
      @minutes = parse_field(minute, 0..59)
      @hours = parse_field(hour, 0..23)
      @days_of_month = parse_field(day_of_month, 1..31)
      @months = parse_field(month, 1..12, MONTHS)
      @days_of_week = parse_days_of_week(day_of_week)
    end

    private def parse_days_of_week(field)
      days_of_week = parse_field(field, 0..7, DAYS)
      if idx = days_of_week.index(0)
        days_of_week.delete(idx)
        days_of_week << 7 unless days_of_week.includes?(7)
      end
      days_of_week
    end

    private def parse_field(field, all_values, names = {} of String => Int32)
      values = [] of Int32
      field.split(',', remove_empty: true) do |value|
        values += parse_field_value(value, all_values, names)
      end
      values.uniq!.sort!
    end

    private def parse_field_value(value, all_values, names)
      case value
      when "*"                     # all
        all_values.to_a
      when %r{^(\d+)$}             # value
        [to_i($1, all_values)]
      when %r{^\*/(\d+)$}          # all/step
        all_values.step($1.to_i).to_a
      when %r{^(\d+)-(\d+)$}       # range
        (to_i($1, all_values)..to_i($2, all_values)).to_a
      when %r{^(\d+)-(\d+)/(\d+)$} # range/step
        (to_i($1, all_values)..to_i($2, all_values)).step($3.to_i).to_a
      else
        if val = names.try(&.fetch(value.downcase, nil))
          [val]
        else
          raise ParseError.new("invalid value #{value}")
        end
      end
    end

    private def to_i(str, all_values)
      value = str.to_i
      unless all_values.includes?(value)
        raise ParseError.new("invalid value #{value}, expected one of #{all_values.inspect}")
      end
      value
    end

    # Returns the Time at which the CRON is expected to run depending on the
    # given Time (defaults to `Time.local`).
    def next(t = Time.local) : Time
      unless @months.includes?(t.month)
        t = Time.local(*find_next_month_and_day(t), @hours.first, @minutes.first, location: t.location)
        return t if @days_of_week.includes?(t.day_of_week.value)

        unless @days_of_week.includes?(t.day)
          return Time.local(*find_next_day(t), @hours.first, @minutes.first, location: t.location)
        end

        return t
      end

      unless @days_of_month.includes?(t.day) && @days_of_week.includes?(t.day_of_week.value)
        return Time.local(*find_next_day(t), @hours.first, @minutes.first, location: t.location)
      end

      unless @hours.includes?(t.hour)
        return Time.local(*find_next_hour(t), @minutes.first, location: t.location)
      end

      Time.local(*find_next_minute(t), location: t.location)
    end

    private def find_next_month(t)
      @months.each do |month|
        return {t.year, month} if month > t.month
      end
      {t.year + 1, @months.first}
    end

    # Finds the 1st possible day starting in the next month (or the months or
    # years afterwards) that exist (e.g. skip April 31 and February 29 during
    # leap years). Also verifies the day-of-week.
    private def find_next_month_and_day(t)
      loop do
        year, month = find_next_month(t)
        days_in_month = Time.days_in_month(year, month)

        # edge case: skip month where the first day-of-month doesn't exist, for
        # example February 30 or April 31, in which case we must still update
        # `t` to avoid an infinite loop where `t` is stuck forever to the same
        # value:
        if @days_of_month.first > days_in_month
          t = Time.local(year, month, 1, location: t.location)
          next
        end

        @days_of_month.each do |day|
          break if day > days_in_month

          t = Time.local(year, month, day, location: t.location)
          return {year, month, day} if @days_of_week.includes?(t.day_of_week.value)
        end
      end
    end

    private def find_next_day(t)
      days_in_month = Time.days_in_month(t.year, t.month)

      @days_of_month.each do |day|
        next unless day > t.day
        break if day > days_in_month

        t = Time.local(t.year, t.month, day, location: t.location)
        return {t.year, t.month, day} if @days_of_week.includes?(t.day_of_week.value)
      end

      find_next_month_and_day(t)
    end

    private def find_next_hour(t)
      @hours.each do |hour|
        return {t.year, t.month, t.day, hour} if hour > t.hour
      end
      {*find_next_day(t), @hours.first}
    end

    private def find_next_minute(t)
      @minutes.each do |minute|
        return {t.year, t.month, t.day, t.hour, minute} if minute > t.minute
      end
      {*find_next_hour(t), @minutes.first}
    end

    def ==(other : self) : Bool
      @minutes == other.@minutes &&
        @hours == other.@hours &&
        @days_of_month == other.@days_of_month &&
        @months == other.@months &&
        @days_of_week == other.@days_of_week
    end

    def to_s(io : IO)
      io << "#<Earl::CRON cron=\"" << @cron << "\">"
    end
  end
end
