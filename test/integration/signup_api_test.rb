require "test_helper"

class Forefront::SignupApiTest < ActionDispatch::IntegrationTest
  setup do
    @product = Forefront::Product.create!(name: "Widget")
    @key = @product.generate_api_key!
  end

  def signup(body, key: @key)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{key}" if key
    post "/forefront/api/v1/signup", params: body.to_json, headers: headers
  end

  def priya(**overrides)
    { name: "Priya Shah", country_code: "+91", phone: "98765 43210", email: "priya@example.com" }.merge(overrides)
  end

  def json
    JSON.parse(response.body)
  end

  test "a new signup creates the customer and an unassigned ticket to schedule a call" do
    signup(priya(external_id: "user-881"))

    assert_response :created
    assert_equal({ "status" => "ok" }, json)

    customer = Forefront::Customer.find_by!(phone: "9876543210")
    assert_equal [ "Priya Shah", "+91", "priya@example.com" ], [ customer.name, customer.country_code, customer.email ]

    ticket = customer.tickets.sole
    assert ticket.signup?
    assert ticket.high?
    assert ticket.open?
    assert_equal @product, ticket.product
    assert_nil ticket.assigned_to
    assert_equal Forefront::Admin.system_actor, ticket.created_by
    assert_match "Schedule a call", ticket.title
    assert_match "user-881", ticket.description
  end

  test "a signup from a customer we already know reuses them, however the phone is typed" do
    known = Forefront::Customer.create!(name: "Priya", country_code: "+91", phone: "9876543210")

    signup(priya(phone: "+91 098765-43210"))

    assert_response :created
    assert_equal 1, Forefront::Customer.where(phone: "9876543210").count
    assert_equal 1, known.tickets.count
  end

  test "signing up again while the first ticket is open adds a note to it instead of a second ticket" do
    signup(priya)
    signup(priya)

    assert_response :ok
    assert_equal({ "status" => "ok" }, json)
    ticket = Forefront::Ticket.sole
    assert_match "Signed up again", ticket.activities.sole.body
  end

  test "signing up again after the first ticket was dealt with opens a new one" do
    signup(priya)
    Forefront::Ticket.sole.update!(status: "resolved")

    signup(priya)

    assert_response :created
    assert_equal 2, Forefront::Ticket.count
  end

  test "the same customer signing up for another product gets a ticket for that product" do
    other = Forefront::Product.create!(name: "Gadget")
    signup(priya)
    signup(priya, key: other.generate_api_key!)

    assert_response :created
    assert_equal [ @product, other ].sort_by(&:id), Forefront::Ticket.all.map(&:product).sort_by(&:id)
  end

  test "a missing or wrong key is refused" do
    signup(priya, key: nil)
    assert_response :unauthorized
    assert_equal({ "status" => "error", "errors" => [ "Invalid API key" ] }, json)

    signup(priya, key: "ff_wrong")
    assert_response :unauthorized
    assert_equal 0, Forefront::Customer.count
  end

  test "a signup without a name or phone is refused with the reasons" do
    signup(priya(name: "", phone: ""))

    assert_response :unprocessable_entity
    assert_equal "error", json["status"]
    assert_includes json["errors"], "Name can't be blank"
    assert_includes json["errors"], "Phone can't be blank"
    assert_equal 0, Forefront::Ticket.count
  end

  test "an email already on another customer doesn't lose the signup" do
    Forefront::Customer.create!(name: "Someone else", email: "priya@example.com")

    signup(priya)

    assert_response :created
    customer = Forefront::Customer.find_by!(phone: "9876543210")
    assert_nil customer.email
    assert_match "priya@example.com is already on another customer", customer.tickets.sole.description
  end

  test "the signup shows in the audit log as done by System" do
    signup(priya)

    admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: "password123" } }
    get "/forefront/audit_log"
    assert_select "tr", text: /System.*created.*Customer.*Priya Shah/m
    assert_select "tr", text: /System.*created.*Ticket.*Schedule a call/m
  end
end
