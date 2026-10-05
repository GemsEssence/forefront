require "test_helper"

class Forefront::Reports::BucketsTest < ActiveSupport::TestCase
  test "weeks run Monday to Sunday and are clipped to the period" do
    dates = Date.new(2026, 10, 1)..Date.new(2026, 10, 14) # Thursday 1st
    buckets = Forefront::Reports::Buckets.for(dates, "week")
    assert_equal [ Date.new(2026, 10, 1)..Date.new(2026, 10, 4), Date.new(2026, 10, 5)..Date.new(2026, 10, 11),
                   Date.new(2026, 10, 12)..Date.new(2026, 10, 14) ], buckets.map(&:last)
  end

  test "months and quarters label their unit; no breakdown is one Total bucket" do
    dates = Date.new(2026, 1, 1)..Date.new(2026, 12, 31)
    assert_equal %w[Q1\ 2026 Q2\ 2026 Q3\ 2026 Q4\ 2026], Forefront::Reports::Buckets.for(dates, "quarter").map(&:first)
    assert_equal "Jan 2026", Forefront::Reports::Buckets.for(dates, "month").first.first
    assert_equal [ [ "Total", dates ] ], Forefront::Reports::Buckets.for(dates, nil)
  end

  test "fit keeps a breakdown within the column cap, coarsening or dropping it" do
    buckets = Forefront::Reports::Buckets
    quarter = Date.new(2026, 7, 1)..Date.new(2026, 9, 30)
    year = Date.new(2026, 1, 1)..Date.new(2026, 12, 31)
    assert_equal "day", buckets.fit(quarter, "day")
    assert_equal "week", buckets.fit(year, "day")
    assert_equal "month", buckets.fit(Date.new(2020, 1, 1)..Date.new(2026, 12, 31), "week")
    assert_nil buckets.fit(Date.new(1, 1, 1)..Date.new(9999, 12, 31), "day")
    assert_nil buckets.fit(year, nil)
    assert_equal buckets::MAX, buckets.count(Date.new(2026, 1, 1)..(Date.new(2026, 1, 1) + buckets::MAX - 1), "day")
  end
end
