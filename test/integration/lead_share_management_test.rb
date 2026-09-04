require "test_helper"

class Forefront::LeadShareManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @alice = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @bob = Forefront::Admin.create!(name: "Bob", email: "bob-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")

    sign_in_as(@admin)
    post "/forefront/leads", params: { lead: { title: "L", description: "D", customer_id: @customer.id, assigned_to_id: @alice.id, source: "website" } }
    @lead = Forefront::Lead.order(:created_at).last
  end

  test "recording a share shows the split on the lead page and no share prompt when there's only ever been one assignee" do
    get "/forefront/leads/#{@lead.id}"
    assert_no_match "Shared Credit", response.body

    patch "/forefront/leads/#{@lead.id}", params: { lead: { assigned_to_id: @bob.id } }

    get "/forefront/leads/#{@lead.id}"
    assert_match "Shared Credit", response.body
    assert_match "Record Share", response.body

    get "/forefront/leads/#{@lead.id}/lead_share/new"
    assert_response :success
    assert_match "Alice", response.body
    assert_match "Bob", response.body

    post "/forefront/leads/#{@lead.id}/lead_share", params: { lead_share: { percentages: { @alice.id => "35", @bob.id => "65" } } }
    assert_redirected_to "/forefront/leads/#{@lead.id}"

    get "/forefront/leads/#{@lead.id}"
    assert_response :success
    assert_match "35.0%", response.body
    assert_match "65.0%", response.body
    assert_match "Edit Share", response.body
  end

  test "a mismatched split is rejected with a clear error and nothing saved" do
    patch "/forefront/leads/#{@lead.id}", params: { lead: { assigned_to_id: @bob.id } }

    assert_no_difference "Forefront::LeadShare.count" do
      post "/forefront/leads/#{@lead.id}/lead_share", params: { lead_share: { percentages: { @alice.id => "10", @bob.id => "10" } } }
    end
    assert_redirected_to "/forefront/leads/#{@lead.id}"
    follow_redirect!
    assert_match "percentages must add up to 100", response.body
  end
end
