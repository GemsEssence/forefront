require "test_helper"

class Forefront::Dashboard::RenewalsTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
  end

  # A won lead whose Subscription expires `in_days` from today.
  def subscriber(name, in_days)
    customer = Forefront::Customer.create!(name: name, phone: unique_phone)
    Forefront::Lead.create!(title: "#{name} deal", description: "D", customer: customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                            product: @product, status: "won", actual_amount: 1000, expires_at: in_days.days.from_now.to_date)
    customer
  end

  def renewal_ticket(customer)
    Forefront::Ticket.create!(title: "Renew #{customer.name}", description: "D", customer: customer, product: @product, created_by: @rep,
                              assigned_to: @rep, category: "renewal", priority: "medium", status: "open")
  end

  test "my renewal tickets show days to expiry" do
    renewal_ticket(subscriber("Acme", 12))
    sign_in_as(@rep)

    get "/forefront/"

    assert_equal "1", metric(:renewal_tickets)
    assert_match(/Renew Acme.*12 days/, widget("renewal_tickets").text.squish)
    assert_equal 1, drill(:renewal_tickets).size
  end

  test "subscriptions expiring within 30 days with no renewal ticket, or one nobody acted on, are at risk" do
    subscriber("No Ticket", 10)
    renewal_ticket(subscriber("Untouched", 20))
    contacted = renewal_ticket(subscriber("Contacted", 15))
    Forefront::AuditEvent.record!(actor: @rep, action: "added_activity", auditable: contacted, audited_changes: {})
    subscriber("Far Off", 90)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "2", metric(:renewal_risk)
    assert_equal [ "No Ticket", "Untouched" ], drill(:renewal_risk).map { |row| row.split(" Widget").first }.sort
    assert_response :success
  end

  test "last cycle's resolved renewal ticket doesn't count as contacting the customer about this one" do
    renewed = subscriber("Renewed Last Year", 10)
    old = renewal_ticket(renewed)
    Forefront::AuditEvent.record!(actor: @rep, action: "added_activity", auditable: old, audited_changes: {})
    old.update_columns(status: "resolved", created_at: 1.year.ago)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "1", metric(:renewal_risk)
    assert_match "Renewed Last Year", drill(:renewal_risk).first
  end
end
