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

    assert_match(/\APrice \(3\) · Timing \(2\) · (Rival|Budget) \(1\) · all 7\z/, cell("Ravi Rep", "lost_by_reason"))
    assert_equal 3, drill(:leads_lost, member_id: @ravi.id, slice: price.id).size
  end

  test "past the top three, an all link opens every lost lead, and each reason link carries its slice" do
    reasons = { "Price" => 4, "Timing" => 3, "Rival" => 2, "Budget" => 1 }.map do |name, count|
      reason = Forefront::LostReason.create!(name: name)
      count.times { lose(reason) }
      reason
    end
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "Price (4) · Timing (3) · Rival (2) · all 10", cell("Ravi Rep", "lost_by_reason")
    links = css_select("tr[data-row='Ravi Rep'] td[data-column='lost_by_reason'] a")
    assert_equal [ reasons[0].id.to_s, reasons[1].id.to_s, reasons[2].id.to_s, nil ], links.map { |link| link["data-slice"] }
    assert_nil URI.parse(links.last["href"]).query.to_s[/slice=/]
    assert_equal 10, drill(:leads_lost, member_id: @ravi.id).size
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
