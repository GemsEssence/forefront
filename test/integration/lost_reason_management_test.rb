require "test_helper"

class Forefront::LostReasonManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
  end

  test "an admin adds, renames, deactivates and deletes lost reasons" do
    sign_in_as(@admin)

    post "/forefront/lost_reasons", params: { lost_reason: { name: "Too expensiv" } }
    assert_redirected_to "/forefront/lost_reasons"
    reason = Forefront::LostReason.find_by!(name: "Too expensiv")

    patch "/forefront/lost_reasons/#{reason.id}", params: { lost_reason: { name: "Too expensive" } }
    patch "/forefront/lost_reasons/#{reason.id}", params: { lost_reason: { active: "0" } }
    get "/forefront/lost_reasons"
    assert_select "h1", text: "Lost reasons"
    assert_select "tr", text: /Too expensive.*Inactive/m

    delete "/forefront/lost_reasons/#{reason.id}"
    get "/forefront/lost_reasons"
    assert_select "tr", text: /Too expensive/, count: 0
  end

  test "lost reason names are unique regardless of case" do
    Forefront::LostReason.create!(name: "No response")
    sign_in_as(@admin)

    post "/forefront/lost_reasons", params: { lost_reason: { name: "no response" } }

    assert_response :unprocessable_entity
    assert_match "Name has already been taken", response.body
  end

  test "changes to lost reasons are audited" do
    sign_in_as(@admin)
    post "/forefront/lost_reasons", params: { lost_reason: { name: "Went with a competitor" } }

    get "/forefront/audit_log"
    assert_select "tr", text: /Asha Admin.*created.*Lost reason.*Went with a competitor/m
  end

  test "managers can't manage lost reasons" do
    manager = Forefront::Admin.create!(name: "Mona", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    sign_in_as(manager)

    get "/forefront/lost_reasons"
    assert_redirected_to "/forefront/"
  end
end
