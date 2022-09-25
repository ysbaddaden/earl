require "./test_helper"
require "../src/cron"

class Earl::CRONTest < Minitest::Test
  def test_parse_errors
    assert_raises(CRON::ParseError) { CRON.new("") }
    assert_raises(CRON::ParseError) { CRON.new("*") }
    assert_raises(CRON::ParseError) { CRON.new("* *") }
    assert_raises(CRON::ParseError) { CRON.new("* * *") }
    assert_raises(CRON::ParseError) { CRON.new("* * * *") }
    assert_raises(CRON::ParseError) { CRON.new("ù * * * *") }
    assert_raises(CRON::ParseError) { CRON.new("* ù * * *") }
    assert_raises(CRON::ParseError) { CRON.new("* * ù * *") }
    assert_raises(CRON::ParseError) { CRON.new("* * * ù *") }
    assert_raises(CRON::ParseError) { CRON.new("* * * * ù") }
  end

  def test_parses_minutes
    assert_equal (0..59).to_a, CRON.new("* * * * *").@minutes
    assert_equal [10, 20, 30], CRON.new("10,30,20 * * * *").@minutes
    assert_equal (40..50).to_a, CRON.new("40-50 * * * *").@minutes
    assert_equal (0..59).step(2).to_a, CRON.new("*/2 * * * *").@minutes
    assert_equal (10..30).step(3).to_a, CRON.new("10-30/3 * * * *").@minutes

    assert_equal ([1] + (2..15).to_a + (0..59).step(3).to_a).uniq!.sort!,
      CRON.new("1,2-15,*/3 * * * *").@minutes

    assert_raises(CRON::ParseError) { CRON.new("-1 * * * *") }
    assert_raises(CRON::ParseError) { CRON.new("60 * * * *") }
    assert_raises(CRON::ParseError) { CRON.new("1-60 * * * *") }
    assert_raises(CRON::ParseError) { CRON.new("1-60/5 * * * *") }
  end

  def test_parses_hours
    assert_equal (0..23).to_a, CRON.new("* * * * *").@hours
    assert_equal [1, 5, 23], CRON.new("* 1,5,23 * * *").@hours
    assert_equal (10..20).to_a, CRON.new("* 10-20 * * *").@hours
    assert_equal (0..23).step(2).to_a, CRON.new("* */2 * * *").@hours
    assert_equal (10..20).step(3).to_a, CRON.new("* 10-20/3 * * *").@hours

    assert_equal ([1] + (2..10).to_a + (0..23).step(4).to_a).uniq!.sort!,
      CRON.new("* 1,2-10,*/4 * * *").@hours

    assert_raises(CRON::ParseError) { CRON.new("* -1 * * *") }
    assert_raises(CRON::ParseError) { CRON.new("* 24 * * *") }
    assert_raises(CRON::ParseError) { CRON.new("* 1-24 * * *") }
    assert_raises(CRON::ParseError) { CRON.new("* 1-24/5 * * *") }
  end

  def test_parses_days_of_month
    assert_equal (1..31).to_a, CRON.new("* * * * *").@days_of_month
    assert_equal [1, 5, 23], CRON.new("* * 1,5,23 * *").@days_of_month
    assert_equal (10..20).to_a, CRON.new("* * 10-20 * *").@days_of_month
    assert_equal (1..31).step(2).to_a, CRON.new("* * */2 * *").@days_of_month
    assert_equal (10..20).step(3).to_a, CRON.new("* * 10-20/3 * *").@days_of_month

    assert_equal ([1] + (5..15).to_a + (1..31).step(5).to_a).uniq!.sort!,
      CRON.new("* * 1,5-15,*/5 * *").@days_of_month

    assert_raises(CRON::ParseError) { CRON.new("* * -1 * *") }
    assert_raises(CRON::ParseError) { CRON.new("* * 32 * *") }
    assert_raises(CRON::ParseError) { CRON.new("* * 0-31 * *") }
    assert_raises(CRON::ParseError) { CRON.new("* * 0-31/5 * *") }
    assert_raises(CRON::ParseError) { CRON.new("* * 1-32 * *") }
    assert_raises(CRON::ParseError) { CRON.new("* * 1-32/5 * *") }
  end

  def test_parses_months
    assert_equal (1..12).to_a, CRON.new("* * * * *").@months
    assert_equal [1, 2, 3, 6, 7, 10, 11], CRON.new("* * * 1,2,3,6,7,10,11 *").@months
    assert_equal [1, 2, 3, 4, 5, 10, 11, 12], CRON.new("* * * 1-5,10-12 *").@months
    assert_equal [1, 3, 5, 7, 9, 11], CRON.new("* * * */2 *").@months
    assert_equal [2, 5, 8, 11], CRON.new("* * * 2-11/3 *").@months
    assert_equal [2, 6], CRON.new("* * * 2-8/4 *").@months

    CRON::MONTHS.each do |name, value|
      assert_equal [value], CRON.new("* * * #{name} *").@months
      assert_equal [value], CRON.new("* * * #{name.upcase} *").@months
    end
    assert_equal [1, 8, 9], CRON.new("* * * jan,aug,sep *").@months

    assert_raises(CRON::ParseError) { CRON.new("* * * 0 *") }
    assert_raises(CRON::ParseError) { CRON.new("* * * 13 *") }
    assert_raises(CRON::ParseError) { CRON.new("* * * 0-12 *") }
    assert_raises(CRON::ParseError) { CRON.new("* * * 1-13 *") }
    assert_raises(CRON::ParseError) { CRON.new("* * * wro *") }
  end

  def test_parses_days_of_week
    assert_equal (1..7).to_a, CRON.new("* * * * *").@days_of_week

    # 0 and 7 are both sunday, keep only 7
    assert_equal [7], CRON.new("* * * * 0").@days_of_week
    assert_equal [1, 5, 7], CRON.new("* * * * 0,1,7,5").@days_of_week

    assert_equal [1, 2, 6, 7], CRON.new("* * * * 1,2,6,7").@days_of_week
    assert_equal [1, 2, 5, 6, 7], CRON.new("* * * * 0-2,5-7").@days_of_week
    assert_equal [2, 4, 6, 7], CRON.new("* * * * */2").@days_of_week # remember that sunday is also 0 (which we translate to 7)
    assert_equal [2, 5], CRON.new("* * * * 2-6/3").@days_of_week
    assert_equal [2], CRON.new("* * * * 2-5/4").@days_of_week

    CRON::DAYS.each do |name, value|
      assert_equal [value], CRON.new("* * * * #{name}").@days_of_week
      assert_equal [value], CRON.new("* * * * #{name.upcase}").@days_of_week
    end
    assert_equal [1, 5], CRON.new("* * * * mon,fri").@days_of_week
  end

  def test_parses_extensions
    CRON::EXTENSIONS.each do |name, value|
      assert_equal CRON.new(name), CRON.new(value)
    end
  end

  def test_every_minute
    cron = CRON.new("* * * * *")

    # skips to the next minute
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-13T12:12:00+0100"
    assert_next cron, "2022-01-13T12:11:30+0100", "2022-01-13T12:12:00+0100"
    assert_next cron, "2022-01-13T12:12:00+0100", "2022-01-13T12:13:00+0100"

    # skips to the next hour, day, month, year
    assert_next cron, "2021-12-31T23:59:00+0100", "2022-01-01T00:00:00+0100"
  end

  def test_every_hour_at_minutes
    cron = CRON.new("13-15,20,22 * * * *")

    # skips to next selected minutes
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-13T12:13:00+0100"
    assert_next cron, "2022-01-13T12:13:00+0100", "2022-01-13T12:14:00+0100"
    assert_next cron, "2022-01-13T12:14:00+0100", "2022-01-13T12:15:00+0100"
    assert_next cron, "2022-01-13T12:15:00+0100", "2022-01-13T12:20:00+0100"
    assert_next cron, "2022-01-13T12:20:00+0100", "2022-01-13T12:22:00+0100"
    assert_next cron, "2022-01-13T12:22:00+0100", "2022-01-13T13:13:00+0100"

    # skips to next day, month, year
    assert_next cron, "2022-01-13T23:30:00+0100", "2022-01-14T00:13:00+0100"
    assert_next cron, "2022-01-31T23:30:00+0100", "2022-02-01T00:13:00+0100"
    assert_next cron, "2021-12-31T23:30:00+0100", "2022-01-01T00:13:00+0100"
  end

  def test_every_day_at_hour
    cron = CRON.new("30 4 * * *")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-14T04:30:00+0100"
    assert_next cron, "2022-01-14T04:30:00+0100", "2022-01-15T04:30:00+0100"
    assert_next cron, "2021-12-31T00:00:00+0100", "2021-12-31T04:30:00+0100"
    assert_next cron, "2021-12-31T04:30:00+0100", "2022-01-01T04:30:00+0100"
  end

  def test_every_some_day_of_month
    cron = CRON.new("15 14 1,15 * *")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-15T14:15:00+0100"
    assert_next cron, "2022-01-15T15:14:00+0100", "2022-02-01T14:15:00+0100"

    cron = CRON.new("15 14 31 * *")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-31T14:15:00+0100"
    assert_next cron, "2022-01-31T14:15:00+0100", "2022-03-31T14:15:00+0100"
    assert_next cron, "2022-03-31T14:15:00+0100", "2022-05-31T14:15:00+0100"
  end

  def test_every_day_of_some_months
    cron = CRON.new("15 14 * 1,3 *")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-13T14:15:00+0100"
    assert_next cron, "2022-01-13T14:15:00+0100", "2022-01-14T14:15:00+0100"
    assert_next cron, "2022-01-31T14:15:00+0100", "2022-03-01T14:15:00+0100"
    assert_next cron, "2022-03-01T14:15:00+0100", "2022-03-02T14:15:00+0100"
    assert_next cron, "2022-03-31T14:15:00+0100", "2023-01-01T14:15:00+0100"
  end

  def test_every_working_weekday
    cron = CRON.new("0 22 * * 1-5")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-13T22:00:00+0100" # thursday
    assert_next cron, "2022-01-13T22:00:00+0100", "2022-01-14T22:00:00+0100" # friday
    assert_next cron, "2022-01-14T22:00:00+0100", "2022-01-17T22:00:00+0100" # skip to monday
    assert_next cron, "2022-01-17T22:00:00+0100", "2022-01-18T22:00:00+0100" # tuesday
    assert_next cron, "2022-01-18T22:00:00+0100", "2022-01-19T22:00:00+0100" # wednesday
  end

  def test_every_working_weekday_but_wednesday
    cron = CRON.new("0 22 * * 1,2,4,5")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-13T22:00:00+0100" # thursday
    assert_next cron, "2022-01-13T22:00:00+0100", "2022-01-14T22:00:00+0100" # friday
    assert_next cron, "2022-01-14T22:00:00+0100", "2022-01-17T22:00:00+0100" # skip to monday
    assert_next cron, "2022-01-17T22:00:00+0100", "2022-01-18T22:00:00+0100" # tuesday
    assert_next cron, "2022-01-18T22:00:00+0100", "2022-01-20T22:00:00+0100" # skip to thursday

    # crosses wednesday, month and year
    assert_next cron, "2019-12-31T22:00:00+0100", "2020-01-02T22:00:00+0100"
  end

  def test_every_weekend_day
    cron = CRON.new("0 22 * * 6,7")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-01-15T22:00:00+0100" # saturday
    assert_next cron, "2022-01-15T22:00:00+0100", "2022-01-16T22:00:00+0100" # sunday
    assert_next cron, "2022-01-16T22:00:00+0100", "2022-01-22T22:00:00+0100" # skip to next saturday

    # crosses month and year
    assert_next cron, "2021-12-31T00:00:00+0100", "2022-01-01T22:00:00+0100"
  end

  def test_day_of_week_matches_with_months
    cron = CRON.new("54 0 * 3,5 sun")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-03-06T00:54:00+0100"
    assert_next cron, "2022-03-06T22:00:00+0100", "2022-03-13T00:54:00+0100"
    assert_next cron, "2022-03-31T00:00:00+0100", "2022-05-01T00:54:00+0100"
  end

  def test_day_of_week_matches_with_day_of_months
    cron = CRON.new("0 22 3,5 * sun")
    assert_next cron, "2022-01-13T12:11:00+0100", "2022-04-03T22:00:00+0100"
    assert_next cron, "2022-04-03T12:11:00+0100", "2022-04-03T22:00:00+0100"
    assert_next cron, "2022-04-03T23:00:00+0100", "2022-06-05T22:00:00+0100"
  end

  private def assert_next(cron, time, expected, message = nil, file = __FILE__, line = __LINE__)
    assert_equal Time.parse_iso8601(expected), cron.next(Time.parse_iso8601(time)), message, file, line
  end
end
