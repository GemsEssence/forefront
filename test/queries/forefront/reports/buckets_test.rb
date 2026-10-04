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
end
