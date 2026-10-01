require "test_helper"

class Forefront::ContactRevealTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @priya = Forefront::Customer.create!(name: "Priya Shah", email: "priya@gmail.com", country_code: "+91", phone: "9876543210")
    sign_in_as(@rep)
  end

  # As the browser sends it: the button submits through Turbo.
  def reveal
    post "/forefront/customers/#{@priya.id}/contact_reveal", headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
  end

  test "the customer page offers to show the contact details" do
    get "/forefront/customers/#{@priya.id}"

    assert_select "#contact_details_customer_#{@priya.id} form[action='/forefront/customers/#{@priya.id}/contact_reveal'] button", text: "Show contact details"
  end

  test "revealing shows the details in place, set to hide again after a minute" do
    reveal

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target='contact_details_customer_#{@priya.id}']" do
      assert_select "template" do
        assert_select "[data-hide-after-seconds='60']"
      end
    end
    assert_match "+91 9876543210", response.body
    assert_match "priya@gmail.com", response.body
  end

  test "each reveal is recorded and shows in the audit log, without the details" do
    reveal

    admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(admin)
    get "/forefront/audit_log"
    assert_select "tr", text: /Ravi Rep.*revealed contact.*Customer.*Priya Shah/m
  end

  test "an admin isn't asked to reveal anything" do
    admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(admin)
    get "/forefront/customers/#{@priya.id}"

    assert_select "button", text: "Show contact details", count: 0
  end
end
