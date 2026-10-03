require "test_helper"

class Forefront::Dashboard::MetricsTest < ActiveSupport::TestCase
  test "defining a key that is already registered raises instead of silently replacing it" do
    error = assert_raises(ArgumentError) do
      Forefront::Dashboard::Metrics.define(:overdue_followups, title: "Again", kind: :followups) { |scope, _| scope.followups }
    end

    assert_match(/overdue_followups/, error.message)
    assert_equal "Overdue Followups", Forefront::Dashboard::Metrics.fetch(:overdue_followups).title
  end
end
