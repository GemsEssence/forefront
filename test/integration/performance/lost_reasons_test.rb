require "test_helper"

class Forefront::Performance::LostReasonsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lose(reason)
    lead = Forefront::Lead.create!(title: "Lost to #{reason.name}", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, status: "lost", lost_reason: reason, lost_note: "N")
    Forefront::StatusHistory.create!(trackable: lead, old_status: "Demo", new_status: "Lost", changed_by: @ravi)
    lead
  end

  test "the top three reasons, most frequent first, each opening its leads" do
    price, timing, rival, budget = %w[Price Timing Rival Budget].map { |name| Forefront::LostReason.create!(name: name) }
    3.times { lose(price) }
    2.times { lose(timing) }
    lose(rival)
    lose(budget)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_match(/\APrice \(3\) · Timing \(2\) · (Rival|Budget) \(1\)\z/, cell("Ravi Rep", "lost_by_reason"))
    assert_equal 3, drill(:leads_lost, member_id: @ravi.id, slice: price.id).size
  end

  test "no lost leads shows a dash, and a Lead lost before the period does not count" do
    price = Forefront::LostReason.create!(name: "Price")
    old = lose(price)
    Forefront::StatusHistory.where(trackable: old).update_all(created_at: 2.months.ago)
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal 1, row_labels.count("Ravi Rep")
    assert_equal "—", cell("Ravi Rep", "lost_by_reason")
  end
end
