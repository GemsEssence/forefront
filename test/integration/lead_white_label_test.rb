require "test_helper"

class Forefront::LeadWhiteLabelTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Branded app", description: "D", customer: @customer, created_by: @admin, source: forefront_source, status: "open")
    sign_in_as(@admin)
  end

  test "an ordinary lead shows nothing about an agreement" do
    get "/forefront/leads/#{@lead.id}"

    assert_no_match "White-label", response.body
    assert_no_match "Agreement", response.body
  end

  test "a white-label lead shows its agreement isn't signed yet" do
    patch "/forefront/leads/#{@lead.id}", params: { lead: { white_label: "1" } }

    get "/forefront/leads/#{@lead.id}"
    assert_match "White-label", response.body
    assert_match "Agreement not signed yet", response.body
  end

  test "recording when a white-label lead's agreement was signed" do
    patch "/forefront/leads/#{@lead.id}", params: { lead: { white_label: "1", agreement_signed_on: "2026-10-12" } }

    get "/forefront/leads/#{@lead.id}"
    assert_match "Agreement signed 12 Oct 2026", response.body
  end

  test "only a white-label lead can have a signed agreement" do
    patch "/forefront/leads/#{@lead.id}", params: { lead: { white_label: "0", agreement_signed_on: "2026-10-12" } }

    assert_response :unprocessable_entity
    assert_match "Agreement signed on can only be set for a white-label lead", response.body
  end

  test "the lead form has the white-label and agreement fields" do
    get "/forefront/leads/#{@lead.id}/edit"

    assert_select "input[type=checkbox][name='lead[white_label]']"
    assert_select "input[type=date][name='lead[agreement_signed_on]']"
  end
end
