require "test_helper"

class Forefront::TicketConversionTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @campaign = Forefront::Campaign.create!(name: "LinkedIn September", starts_on: "2026-09-01", ends_on: "2026-09-30",
                                            source: forefront_source("LinkedIn"), created_by: @rep)
    @ticket = Forefront::Ticket.create!(title: "Enquiry: Acme about Widget", description: "Wants 20 seats", customer: @customer,
                                        product: @product, campaign: @campaign, created_by: @rep, assigned_to: @rep,
                                        category: "enquiry", priority: "medium", status: "in_progress")
    sign_in_as(@rep)
  end

  # As the form sends it, with the Source it pre-selects.
  def convert(ticket = @ticket, **lead)
    post "/forefront/tickets/#{ticket.id}/conversion",
         params: { lead: { title: "Acme Widget rollout", estimated_amount: "50000", source_id: @campaign.source_id }.merge(lead), first_step: forefront_first_step }
  end

  test "converting a ticket opens a lead from it, at Contacted, and the ticket becomes its first ticket" do
    convert

    lead = Forefront::Lead.find_by!(title: "Acme Widget rollout")
    assert_redirected_to "/forefront/leads/#{lead.id}"
    assert lead.contacted?
    assert_equal [ @customer, @product, @rep, @campaign ], [ lead.customer, lead.product, lead.assigned_to, lead.campaign ]
    assert_equal 50_000, lead.estimated_amount
    assert_equal "Wants 20 seats", lead.description

    @ticket.reload
    assert_equal lead, @ticket.lead
    assert @ticket.resolved?
    assert_equal "Converted to lead Acme Widget rollout", @ticket.status_histories.last.note
  end

  test "the lead's source starts as the campaign's, or Signup for a signup ticket" do
    get "/forefront/tickets/#{@ticket.id}"
    assert_select "form[action='/forefront/tickets/#{@ticket.id}/conversion'] select[name='lead[source_id]'] option[selected]", text: "LinkedIn"

    signup = Forefront::Ticket.create!(title: "Schedule a call", description: "D", customer: @customer, product: @product,
                                       created_by: @rep, assigned_to: @rep, category: "signup", priority: "high", status: "open")
    get "/forefront/tickets/#{signup.id}"
    assert_select "select[name='lead[source_id]'] option[selected]", text: "Signup"
  end

  test "the source can be changed when converting" do
    convert(source_id: forefront_source("Referral").id)

    assert_equal "Referral", Forefront::Lead.sole.source.name
  end

  test "a ticket already under a lead can't be converted again" do
    convert
    lead = Forefront::Lead.sole

    convert(title: "Second try")

    assert_equal [ lead ], Forefront::Lead.all.to_a
    get "/forefront/tickets/#{@ticket.id}"
    assert_select "form[action='/forefront/tickets/#{@ticket.id}/conversion']", 0
  end

  test "a renewal ticket can't be converted" do
    renewal = Forefront::Ticket.create!(title: "Renew", description: "D", customer: @customer, product: @product, created_by: @rep,
                                        assigned_to: @rep, category: "renewal", priority: "medium", status: "open")

    convert(renewal)

    assert_equal 0, Forefront::Lead.count
  end

  test "someone who can't work the ticket can't convert it" do
    other = Forefront::Admin.create!(name: "Meera Rep", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    sign_in_as(other)

    convert

    assert_equal 0, Forefront::Lead.count
  end

  test "converting is audited" do
    convert
    admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(admin)

    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*converted.*Ticket.*Enquiry: Acme about Widget.*Lead: — → Acme Widget rollout/m
  end
end
