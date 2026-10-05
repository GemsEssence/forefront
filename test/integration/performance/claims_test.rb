require "test_helper"

class Forefront::Performance::ClaimsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  # Records here are made hours ago and read under the default "This month",
  # so pin the clock mid-month; just after midnight on the 1st they would fall into last month.
  setup do
    travel_to Time.zone.local(2026, 10, 20, 12)
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def pooled_ticket(title, created_at:)
    Forefront::Ticket.create!(title: title, description: "D", customer: @customer, created_by: @manager, category: "signup",
                              priority: "high", status: "open", created_at: created_at)
  end

  def take(record, by:, at:)
    travel_to(at) do
      record.assignments.create!(to_user: by, changed_by: by, from_user: nil)
      record.update_columns(assigned_to_id: by.id)
    end
  end

  test "records taken from the pool count, with the mean wait in hours; ones you created yourself don't" do
    take(pooled_ticket("Waited 2h", created_at: 3.hours.ago), by: @ravi, at: 1.hour.ago)
    take(pooled_ticket("Waited 4h", created_at: 5.hours.ago), by: @ravi, at: 1.hour.ago)
    own = Forefront::Ticket.create!(title: "Mine", description: "D", customer: @customer, created_by: @ravi, category: "request",
                                    priority: "medium", status: "open", created_at: 2.hours.ago)
    take(own, by: @ravi, at: 1.hour.ago)
    given = pooled_ticket("Given", created_at: 2.hours.ago)
    travel_to(1.hour.ago) { given.assignments.create!(to_user: @ravi, changed_by: @manager, from_user: nil) }
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "2", cell("Ravi Rep", "records_claimed")
    assert_equal "3.0 h", cell("Ravi Rep", "avg_time_to_claim")
    rows = drill(:claims, member_id: @ravi.id)
    assert_response :success
    assert_equal [ "Waited 2h", "Waited 4h" ], rows.map { |row| row[/Waited \dh/] }.sort
  end

  test "no claims shows a dash for the average" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_equal "0", cell("Ravi Rep", "records_claimed")
    assert_equal "—", cell("Ravi Rep", "avg_time_to_claim")
  end
end
