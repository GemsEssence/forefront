require "test_helper"

class Forefront::CustomerPhoneTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    sign_in_as(@admin)
  end

  def create_customer(name, country_code:, phone:)
    post "/forefront/customers", params: { customer: { name: name, country_code: country_code, phone: phone } }
  end

  test "the customer form asks for a country code, defaulting to the configured one" do
    get "/forefront/customers/new"

    assert_select "input[name='customer[country_code]'][value='+91']"
  end

  test "a phone number is stored as its digits, without a trunk zero, and shown with its country code" do
    create_customer("Priya", country_code: "+91", phone: "098765-43210")
    priya = Forefront::Customer.find_by!(name: "Priya")

    assert_equal [ "+91", "9876543210" ], [ priya.country_code, priya.phone ]
    get "/forefront/customers/#{priya.id}"
    assert_match "+91 9876543210", response.body
  end

  test "a phone typed with its own country code in front is accepted" do
    create_customer("Priya", country_code: "+91", phone: "+91 98765 43210")

    assert_equal "9876543210", Forefront::Customer.find_by!(name: "Priya").phone
  end

  test "a phone typed with a different country code is refused" do
    create_customer("Sam", country_code: "+91", phone: "+1 555 010 0199")

    assert_response :unprocessable_entity
    assert_match "Phone starts with a different country code; put it in Country code instead", response.body
  end

  test "two customers can't share a number in the same country, however it was typed" do
    create_customer("Priya", country_code: "+91", phone: "9876543210")
    create_customer("Priya again", country_code: "+91", phone: "098765 43210")

    assert_response :unprocessable_entity
    assert_match "Phone is already used by another customer", response.body
  end

  test "the same digits in another country are a different number" do
    create_customer("Priya", country_code: "+91", phone: "9876543210")
    create_customer("Pat", country_code: "+44", phone: "9876543210")

    assert Forefront::Customer.exists?(name: "Pat")
  end

  test "a country code must look like +91" do
    create_customer("Priya", country_code: "91x", phone: "9876543210")

    assert_response :unprocessable_entity
    assert_match "Country code must be a + followed by 1 to 4 digits", response.body
  end

  test "filtering by phone finds the customer however the number is typed" do
    create_customer("Priya", country_code: "+91", phone: "9876543210")

    get "/forefront/customers", params: { phone: "98765-43210" }

    assert_match "Priya", response.body
  end
end
