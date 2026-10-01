require "test_helper"

class Forefront::CampaignEnquiryTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @widget = Forefront::Product.create!(name: "Widget")
    @gadget = Forefront::Product.create!(name: "Gadget")
    @linkedin = Forefront::Campaign.create!(name: "LinkedIn September", starts_on: "2026-09-01", ends_on: "2026-09-30",
                                            source: forefront_source("LinkedIn"), created_by: @rep)
    @gitex = Forefront::Campaign.create!(name: "Gitex 2026", starts_on: "2026-10-12", ends_on: "2026-10-16",
                                         source: forefront_source("Gitex"), created_by: @rep)
    sign_in_as(@rep)
  end

  def record_enquiry(campaign, product, **overrides)
    post "/forefront/campaigns/#{campaign.id}/enquiries",
         params: { enquiry: { name: "Priya Shah", country_code: "+91", phone: "98765 43210", product_id: product&.id,
                              note: "Saw the ad, wants pricing" }.merge(overrides) }
  end

  test "an enquiry creates the customer and a ticket credited to the campaign" do
    record_enquiry(@linkedin, @widget)

    customer = Forefront::Customer.find_by!(phone: "9876543210")
    ticket = customer.tickets.sole
    assert_redirected_to "/forefront/tickets/#{ticket.id}"
    assert ticket.enquiry?
    assert_equal [ @linkedin, @widget, @rep ], [ ticket.campaign, ticket.product, ticket.assigned_to ]
    assert_match "Saw the ad, wants pricing", ticket.description

    get "/forefront/campaigns/#{@linkedin.id}"
    assert_select "#campaign_enquiries a[href='/forefront/tickets/#{ticket.id}']"
    get "/forefront/tickets/#{ticket.id}"
    assert_select "a[href='/forefront/campaigns/#{@linkedin.id}']", text: "LinkedIn September"
  end

  test "a customer we already know is reused, however the phone is typed" do
    known = Forefront::Customer.create!(name: "Priya", country_code: "+91", phone: "9876543210")

    record_enquiry(@linkedin, @widget, phone: "098765-43210")

    assert_equal 1, Forefront::Customer.count
    assert_equal 1, known.tickets.count
  end

  test "a second campaign for a product the customer already has open adds a note and keeps the first campaign's credit" do
    record_enquiry(@linkedin, @widget)
    record_enquiry(@gitex, @widget, note: "Met them at the stand")

    ticket = Forefront::Ticket.sole
    assert_equal @linkedin, ticket.campaign
    assert_match "Also came via Gitex 2026", ticket.activities.sole.body
    assert_match "Met them at the stand", ticket.activities.sole.body
  end

  test "an open ticket with no campaign yet, like a signup, is credited to this one" do
    customer = Forefront::Customer.create!(name: "Priya", country_code: "+91", phone: "9876543210")
    signup = Forefront::Ticket.create!(title: "Schedule a call", description: "D", customer: customer, product: @widget,
                                       created_by: Forefront::Admin.system_actor, category: "signup", priority: "high", status: "open")

    record_enquiry(@linkedin, @widget)

    assert_equal @linkedin, signup.reload.campaign
    assert_equal 1, Forefront::Ticket.count
  end

  test "an enquiry about another product is a separate ticket, and the customer shows both campaigns" do
    record_enquiry(@linkedin, @widget)
    record_enquiry(@gitex, @gadget)

    customer = Forefront::Customer.sole
    assert_equal 2, customer.tickets.count
    get "/forefront/customers/#{customer.id}"
    assert_match "LinkedIn September", response.body
    assert_match "Gitex 2026", response.body
  end

  test "an enquiry needs a product and a phone" do
    record_enquiry(@linkedin, nil, phone: "")

    assert_redirected_to "/forefront/campaigns/#{@linkedin.id}"
    assert_match "Product must be chosen", flash[:alert]
    assert_match "Phone can't be blank", flash[:alert]
    assert_equal 0, Forefront::Ticket.count
  end

  test "the campaign page has the enquiry form" do
    get "/forefront/campaigns/#{@linkedin.id}"

    assert_select "form[action='/forefront/campaigns/#{@linkedin.id}/enquiries']" do
      assert_select "input[name='enquiry[phone]'][required]"
      assert_select "select[name='enquiry[product_id]'] option", text: "Widget"
    end
  end
end
