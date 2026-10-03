require "test_helper"

class Forefront::Dashboard::PerPersonTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @manager)
    @outsider = dashboard_staff("Otto Outsider", "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def ticket(owner)
    Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: owner, assigned_to: owner, category: "request", priority: "medium", status: "open")
  end

  test "workload has one row per team member, including the manager, and no outsiders" do
    2.times { ticket(@ravi) }
    ticket(@sara)
    ticket(@outsider)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "2", metric(:open_tickets, member: @ravi)
    assert_equal "1", metric(:open_tickets, member: @sara)
    assert_equal "0", metric(:open_tickets, member: @manager)
    assert_nil metric(:open_tickets, member: @outsider)
    assert_equal 2, drill(:open_tickets, member_id: @ravi.id).size
  end

  test "performance shows each person's wins and money, opening their own records" do
    Forefront::Lead.create!(title: "Ravi's win", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi,
                            source: forefront_source, status: "won", actual_amount: 2_500)
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "1", metric(:won, member: @ravi)
    assert_equal "₹2,500.00", css_select("[data-metric='won'][data-member='#{@ravi.id}'][data-sum]").first.text.squish
    assert_equal "0", metric(:won, member: @sara)
  end
end
