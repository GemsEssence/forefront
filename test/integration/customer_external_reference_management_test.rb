require "test_helper"

class Forefront::CustomerExternalReferenceManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    Forefront.plugin_mode = true
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(@admin)
  end

  teardown do
    Forefront.plugin_mode = false
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

  test "customers created without a host application link don't collide" do
    2.times do |i|
      post "/forefront/customers", params: { customer: {
        name: "Walk-in #{i}", email: "walkin-#{i}-#{SecureRandom.hex(4)}@example.com", phone: "555-010#{i}",
        external_type: "", external_id: ""
      } }
      assert_response :redirect, "customer #{i} was rejected"
    end

    walk_ins = Forefront::Customer.where("name LIKE 'Walk-in%'")
    assert_equal 2, walk_ins.count
    assert walk_ins.all? { |c| c.external_type.nil? && c.external_id.nil? }
  end

  test "the host application link fields appear on the customer form in plugin mode" do
    get "/forefront/customers/new"

    assert_match "Host Application Link", response.body
    assert_select "input[name='customer[external_id]']"
  end

  test "outside plugin mode the host application link is hidden and ignored" do
    Forefront.plugin_mode = false

    get "/forefront/customers/new"
    assert_no_match "Host Application Link", response.body
    assert_select "input[name='customer[external_id]']", count: 0

    post "/forefront/customers", params: { customer: {
      name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", external_type: "User", external_id: "7"
    } }
    customer = Forefront::Customer.order(:created_at).last
    assert_nil customer.external_id

    customer.update_columns(external_type: "User", external_id: "7")
    get "/forefront/customers/#{customer.id}"
    assert_no_match "Host Application Link", response.body
  end
end
