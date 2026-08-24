require "test_helper"

class Forefront::AdminOperationsTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Manager", email: "manager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
  end

  test "admin can create a manager with an explicit role and no manager" do
    result = Forefront::AdminOperations::Create.new(
      params: { name: "New Manager", email: "newmanager-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", role: "manager" },
      current_admin: @admin
    ).call

    assert result[:success]
    assert result[:admin].manager?
    assert_nil result[:admin].manager_id
  end

  test "a manager creating staff is always forced to sales_person reporting to themselves, regardless of submitted role/manager_id" do
    other_manager = Forefront::Admin.create!(name: "Other Manager", email: "othermanager-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")

    result = Forefront::AdminOperations::Create.new(
      params: { name: "Sneaky", email: "sneaky-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", role: "admin", manager_id: other_manager.id },
      current_admin: @manager
    ).call

    assert result[:success]
    assert result[:admin].sales_person?
    assert_equal @manager.id, result[:admin].manager_id
  end

  test "update leaves the password untouched when none is submitted" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    original_encrypted_password = rep.encrypted_password

    result = Forefront::AdminOperations::Update.new(
      admin: rep,
      params: { name: "Rep Renamed", email: rep.email, password: "" },
      current_admin: @manager
    ).call

    assert result[:success]
    assert_equal "Rep Renamed", result[:admin].name
    assert_equal original_encrypted_password, result[:admin].reload.encrypted_password
  end

  test "a manager updating their report cannot change role or manager_id" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    other_manager = Forefront::Admin.create!(name: "Other Manager", email: "othermanager2-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")

    result = Forefront::AdminOperations::Update.new(
      admin: rep,
      params: { name: rep.name, email: rep.email, role: "admin", manager_id: other_manager.id },
      current_admin: @manager
    ).call

    assert result[:success]
    assert result[:admin].sales_person?
    assert_equal @manager.id, result[:admin].manager_id
  end

  test "an admin updating a staff member can change role and manager_id" do
    rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)

    result = Forefront::AdminOperations::Update.new(
      admin: rep,
      params: { name: rep.name, email: rep.email, role: "manager", manager_id: nil },
      current_admin: @admin
    ).call

    assert result[:success]
    assert result[:admin].manager?
    assert_nil result[:admin].manager_id
  end
end
