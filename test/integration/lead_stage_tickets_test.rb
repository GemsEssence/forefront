require "test_helper"

class Forefront::LeadStageTicketsTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                    source: forefront_source, product: @product, status: "contacted")
    sign_in_as(@rep)
  end

  def change_stage(stage, **extra)
    post "/forefront/leads/#{@lead.id}/status_histories", params: { status_history: { status: stage, **extra } }
  end

  test "moving to Demo opens a demo ticket under the lead, for its assignee, due in two days" do
    travel_to Time.zone.local(2026, 10, 5, 10) do
      change_stage("demo", note: "Wants to see the reporting module")
    end

    ticket = @lead.tickets.sole
    assert ticket.new_app_demo?
    assert ticket.open?
    assert_equal "Schedule demo", ticket.title
    assert_equal "Wants to see the reporting module", ticket.description
    assert_equal @rep, ticket.assigned_to
    assert_equal [ @customer, @product ], [ ticket.customer, ticket.product ]
    assert_equal Date.new(2026, 10, 7), ticket.due_at
  end

  test "the dialog's due date is used for the new ticket" do
    change_stage("proposal", ticket_due_at: "2026-10-20")

    ticket = @lead.tickets.sole
    assert ticket.proposal?
    assert_equal "Send proposal", ticket.title
    assert_equal Date.new(2026, 10, 20), ticket.due_at
  end

  test "an open ticket of that kind is reused instead of opening a second one" do
    change_stage("demo")
    change_stage("proposal")
    change_stage("demo")

    assert_equal 1, @lead.tickets.new_app_demo.count
    assert_equal 1, @lead.tickets.proposal.count
  end

  test "a second demo after the first was done opens a new ticket" do
    change_stage("demo")
    @lead.tickets.new_app_demo.sole.update!(status: "resolved")
    change_stage("contacted")
    change_stage("demo")

    assert_equal 2, @lead.tickets.new_app_demo.count
  end

  test "other stages open no ticket" do
    change_stage("negotiation")
    change_stage("contacted")

    assert_empty @lead.tickets
  end

  test "the stage dialog asks when the new ticket is due" do
    get "/forefront/leads/#{@lead.id}"

    assert_select "#status_history_modal_lead_#{@lead.id} input[type=date][name='status_history[ticket_due_at]']"
  end
end
