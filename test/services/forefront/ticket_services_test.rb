require "test_helper"

class Forefront::TicketServicesFilterTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @open_ticket = Forefront::Ticket.create!(title: "Open", description: "D", customer: @customer, created_by: @admin, category: "new_app_demo", priority: "medium", status: "open")
    @resolved_ticket = Forefront::Ticket.create!(title: "Resolved", description: "D", customer: @customer, created_by: @admin, category: "new_app_demo", priority: "medium", status: "resolved")
  end

  test "filters by status when called with real controller params, whose keys are Strings, not Symbols" do
    filters = ActionController::Parameters.new(status: "Resolved").permit(:status)

    result = Forefront::TicketServices::Filter.new(scope: Forefront::Ticket.all, filters: filters).call

    assert_equal [ @resolved_ticket ], result.to_a
  end

  test "the search filter is reached and matches on title, given real controller params" do
    filters = ActionController::Parameters.new(search: "Open").permit(:search)

    result = Forefront::TicketServices::Filter.new(scope: Forefront::Ticket.all, filters: filters).call

    assert_equal [ @open_ticket ], result.to_a
  end
end
