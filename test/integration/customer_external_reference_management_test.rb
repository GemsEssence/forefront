require "test_helper"

class Forefront::CustomerExternalReferenceManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(@admin)
  end

  test "creating a customer with a host application link shows it on the show page, and it's findable afterward" do
    post "/forefront/customers", params: { customer: {
      name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100",
      external_type: "User", external_id: "42"
    } }
    customer = Forefront::Customer.order(:created_at).last
    assert_redirected_to "/forefront/customers/#{customer.id}"

    get "/forefront/customers/#{customer.id}"
    assert_response :success
    assert_match "Host Application Link", response.body
    assert_match "User#42", response.body

    assert_equal customer, Forefront::Customer.find_by_external(external_type: "User", external_id: "42")
  end

  test "linking two customers to the same external record is rejected" do
    Forefront::Customer.create!(name: "A", email: "a-#{SecureRandom.hex(4)}@example.com", phone: "555-0100", external_type: "User", external_id: "42")

    assert_no_difference "Forefront::Customer.count" do
      post "/forefront/customers", params: { customer: {
        name: "B", email: "b-#{SecureRandom.hex(4)}@example.com", phone: "555-0100",
        external_type: "User", external_id: "42"
      } }
    end
    assert_response :unprocessable_entity
  end
end
