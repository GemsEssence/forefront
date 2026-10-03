require "test_helper"

class Forefront::Dashboard::UnassignedPoolTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def pooled_ticket(title, age)
    Forefront::Ticket.create!(title: title, description: "D", customer: @customer, created_by: @manager, category: "signup",
                              priority: "high", status: "open", created_at: age.ago)
  end

  test "the pool is counted by age and the oldest are listed with an Assign link" do
    pooled_ticket("Fresh", 30.minutes)
    stale = pooled_ticket("Stale", 5.days)
    Forefront::Lead.create!(title: "Pool lead", description: "D", customer: @customer, created_by: @manager, source: forefront_source("Website"), created_at: 3.hours.ago)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "1", metric(:pool_tickets, slice: "under_2h")
    assert_equal "1", metric(:pool_tickets, slice: "over_3d")
    assert_equal "1", metric(:pool_leads, slice: "2h_24h")
    assert_equal "1", metric(:pool_leads_by_source, slice: forefront_source("Website").id)
    oldest = css_select(widget("unassigned_pool"), "li").map { |item| item.text.squish }
    assert_match(/\AStale.*Assign/, oldest.first)
    assert_select widget("unassigned_pool"), "li a[href='/forefront/tickets/#{stale.id}']", text: "Assign"
    assert_match "Stale", drill(:pool_tickets, slice: "over_3d").first
  end

  test "a sales person can't open the team pool metrics" do
    sign_in_as(dashboard_staff("Ravi Rep", "sales_person"))
    get "/forefront/dashboard/metrics/pool_tickets"
    assert_redirected_to "/forefront/"
  end
end
