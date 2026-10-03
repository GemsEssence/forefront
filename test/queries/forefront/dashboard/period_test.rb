# test/queries/forefront/dashboard/period_test.rb
require "test_helper"

class Forefront::Dashboard::PeriodTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 10, 14) # a Wednesday

  def period(params)
    Forefront::Dashboard::Period.from_params(params, today: TODAY)
  end

  test "defaults to this month" do
    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 10, 31), period({}).dates
    assert_equal "month", period({}).name
  end

  test "named periods are the current calendar unit" do
    assert_equal TODAY..TODAY, period(period: "today").dates
    assert_equal Date.new(2026, 10, 12)..Date.new(2026, 10, 18), period(period: "week").dates
    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 12, 31), period(period: "quarter").dates
    assert_equal Date.new(2026, 1, 1)..Date.new(2026, 12, 31), period(period: "year").dates
  end

  test "a week runs Monday to Sunday even when the host starts weeks on Sunday" do
    host_setting = Date.beginning_of_week
    Date.beginning_of_week = :sunday
    week = period(period: "week")
    assert_equal Date.new(2026, 10, 12)..Date.new(2026, 10, 18), week.dates
    assert_equal Date.new(2026, 10, 5)..Date.new(2026, 10, 11), week.previous.dates
  ensure
    Date.beginning_of_week = host_setting
  end

  test "custom dates are inclusive, swapped when backwards, and fall back when unparseable" do
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 10), period(period: "custom", from: "2026-09-01", to: "2026-09-10").dates
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 10), period(period: "custom", from: "2026-09-10", to: "2026-09-01").dates
    assert_equal Date.new(2026, 10, 1)..TODAY, period(period: "custom", from: "rubbish", to: "").dates
  end

  test "an unknown period name is treated as this month" do
    assert_equal "month", period(period: "decade").name
  end

  test "the previous period is the calendar unit before, or the same number of days before a custom range" do
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 30), period(period: "month").previous.dates
    assert_equal Date.new(2026, 10, 13)..Date.new(2026, 10, 13), period(period: "today").previous.dates
    assert_equal Date.new(2026, 7, 1)..Date.new(2026, 9, 30), period(period: "quarter").previous.dates
    assert_equal Date.new(2026, 8, 22)..Date.new(2026, 8, 31), period(period: "custom", from: "2026-09-01", to: "2026-09-10").previous.dates
  end

  test "params reproduce the period, and times cover whole days" do
    assert_equal({ period: "week" }, period(period: "week").to_params)
    custom = period(period: "custom", from: "2026-09-01", to: "2026-09-10")
    assert_equal({ period: "custom", from: "2026-09-01", to: "2026-09-10" }, custom.to_params)
    assert_equal Date.new(2026, 9, 1).beginning_of_day, custom.times.begin
    assert_equal Date.new(2026, 9, 10).end_of_day, custom.times.end
    assert_equal "1 Sep 2026 – 10 Sep 2026", custom.label
    assert_equal "This week", period(period: "week").label
  end
end
