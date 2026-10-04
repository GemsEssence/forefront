require "test_helper"

class Forefront::ReportsTest < ActiveSupport::TestCase
  test "every registered report has a unique key and is found by it" do
    keys = Forefront::Reports.all.map(&:key)
    assert_equal keys.uniq, keys
    assert_equal Forefront::Reports::LeadStage, Forefront::Reports.find("lead_stage")
    assert_nil Forefront::Reports.find("nope")
  end

  test "registering a key twice raises" do
    assert_raises(ArgumentError) { Forefront::Reports.register("lead_stage", "Forefront::Reports::LeadStage") }
  end
end
