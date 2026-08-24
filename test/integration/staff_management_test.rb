require "test_helper"

class Forefront::StaffManagementTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  test "an admin can list staff, create a manager, and edit a sales person" do
    admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    sign_in_as(admin)

    get "/forefront/staff"
    assert_response :success

    get "/forefront/staff/new"
    assert_response :success

    assert_difference "Forefront::Admin.count", 1 do
      post "/forefront/staff", params: { admin: { name: "New Manager", email: "newmanager-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", role: "manager" } }
    end
    assert_redirected_to "/forefront/staff"
    assert Forefront::Admin.order(:created_at).last.manager?

    get "/forefront/staff/#{rep.id}/edit"
    assert_response :success

    patch "/forefront/staff/#{rep.id}", params: { admin: { name: "Rep Renamed", email: rep.email } }
    assert_redirected_to "/forefront/staff"
    assert_equal "Rep Renamed", rep.reload.name
  end

  test "a sales person cannot reach the staff pages" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    sign_in_as(rep)

    get "/forefront/staff"
    assert_redirected_to "/forefront/"
  end

  test "a manager creating staff through the real form (no role/manager fields submitted) gets a sales person reporting to them" do
    manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    sign_in_as(manager)

    assert_difference "Forefront::Admin.count", 1 do
      post "/forefront/staff", params: { admin: { name: "My Rep", email: "myrep-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123" } }
    end
    created = Forefront::Admin.order(:created_at).last
    assert created.sales_person?
    assert_equal manager.id, created.manager_id
  end

  test "a manager tampering the request to submit a disallowed role is rejected outright, not silently corrected" do
    manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    sign_in_as(manager)

    assert_no_difference "Forefront::Admin.count" do
      post "/forefront/staff", params: { admin: { name: "Sneaky", email: "sneaky-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", role: "admin" } }
    end
    assert_redirected_to "/forefront/"
  end

  test "a manager cannot edit another manager's direct report" do
    other_manager = Forefront::Admin.create!(name: "Other Manager", email: "othermanager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    other_managers_rep = Forefront::Admin.create!(name: "Other Rep", email: "otherrep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: other_manager)
    manager = Forefront::Admin.create!(name: "Manager", email: "manager2-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    sign_in_as(manager)

    get "/forefront/staff/#{other_managers_rep.id}/edit"
    assert_redirected_to "/forefront/"
  end
end
