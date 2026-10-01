require "test_helper"

class Forefront::CustomerContactMaskingTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @priya = Forefront::Customer.create!(name: "Priya Shah", email: "priya@gmail.com", country_code: "+91", phone: "9876543210")
  end

  test "a sales person sees masked contact details on the customer's page and in the list" do
    sign_in_as(@rep)

    [ "/forefront/customers/#{@priya.id}", "/forefront/customers" ].each do |path|
      get path
      assert_match "+91 ••••••3210", response.body, path
      assert_match "p•••@gmail.com", response.body, path
      assert_no_match "9876543210", response.body, path
      assert_no_match "priya@gmail.com", response.body, path
    end
  end

  test "a manager sees them masked too" do
    sign_in_as(@manager)
    get "/forefront/customers/#{@priya.id}"

    assert_no_match "9876543210", response.body
    assert_match "+91 ••••••3210", response.body
  end

  test "an admin sees them in full" do
    sign_in_as(@admin)
    get "/forefront/customers/#{@priya.id}"

    assert_match "+91 9876543210", response.body
    assert_match "priya@gmail.com", response.body
  end

  test "a sales person can still find a customer by phone or email, and the result stays masked" do
    sign_in_as(@rep)

    get "/forefront/customers", params: { phone: "98765 43210" }
    assert_match "Priya Shah", response.body
    assert_no_match "9876543210", response.body

    get "/forefront/customers", params: { search: "priya@gmail" }
    assert_match "Priya Shah", response.body
    assert_no_match "priya@gmail.com", response.body
  end

  test "a sales person's edit form doesn't show the contact details" do
    sign_in_as(@rep)
    get "/forefront/customers/#{@priya.id}/edit"

    assert_no_match "9876543210", response.body
    assert_no_match "priya@gmail.com", response.body
    assert_select "input[name='customer[phone]'][placeholder='+91 ••••••3210']"
  end

  test "leaving masked fields blank keeps them, typing replaces them, without revealing anything" do
    sign_in_as(@rep)

    patch "/forefront/customers/#{@priya.id}", params: { customer: { name: "Priya S", email: "", phone: "", country_code: "" } }
    assert_equal [ "Priya S", "priya@gmail.com", "+91", "9876543210" ], @priya.reload.values_at(:name, :email, :country_code, :phone)

    patch "/forefront/customers/#{@priya.id}", params: { customer: { phone: "91234 56789", country_code: "+91" } }
    assert_equal "9123456789", @priya.reload.phone
  end

  test "an admin's edit form is filled in as usual" do
    sign_in_as(@admin)
    get "/forefront/customers/#{@priya.id}/edit"

    assert_select "input[name='customer[phone]'][value='9876543210']"
  end
end
