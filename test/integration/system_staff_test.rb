require "test_helper"

class Forefront::SystemStaffTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @system = Forefront::Admin.system_actor
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @admin, source: forefront_source, status: "open")
  end

  test "there is exactly one System, named System" do
    assert_equal @system, Forefront::Admin.system_actor
    assert_equal "System", @system.name
    assert_equal 1, Forefront::Admin.where(system: true).count
  end

  test "System can't sign in, even with its password" do
    @system.update!(password: "password123")

    sign_in_as(@system)
    assert_match "Invalid", flash[:alert]

    get "/forefront/leads"
    assert_response :redirect
  end

  test "System isn't offered as someone to give work to, and isn't listed as staff" do
    sign_in_as(@admin)

    get "/forefront/leads/new"
    assert_select "select[name='lead[assigned_to_id]'] option", text: "System", count: 0

    get "/forefront/leads/#{@lead.id}"
    assert_select "option", text: "System", count: 0

    get "/forefront/staff"
    assert_no_match "System", css_select("table, ul").text
  end
end
