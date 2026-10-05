require "test_helper"

class Forefront::TicketAssigneeTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Ada", email: "ada-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Max", email: "max-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Rita", email: "rita-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "assignable staff excludes admins" do
    assignable = Forefront::Admin.assignable
    assert_includes assignable, @manager
    assert_includes assignable, @rep
    assert_not_includes assignable, @admin
  end

  test "a ticket cannot be assigned to an admin" do
    ticket = build_ticket(assigned_to: @admin)

    assert_not ticket.valid?
    assert_includes ticket.errors[:assigned_to], "can't be an admin"
  end

  test "a ticket can be assigned to a manager or sales person" do
    assert build_ticket(assigned_to: @manager).valid?
    assert build_ticket(assigned_to: @rep).valid?
  end

  test "tickets already assigned to an admin stay editable" do
    ticket = build_ticket(assigned_to: @rep)
    ticket.save!
    ticket.update_column(:assigned_to_id, @admin.id)

    assert ticket.reload.update(title: "Renamed")
  end

  test "an admin creating an unassigned ticket leaves it unassigned" do
    result = Forefront::TicketOperations::Create.new(
      params: ActionController::Parameters.new(title: "T", description: "D", customer_id: @customer.id, category: "new_app_demo", priority: "medium"),
      current_admin: @admin
    ).call

    assert result[:success], result[:errors].inspect
    assert_nil result[:ticket].assigned_to
  end

  test "a sales person creating an unassigned ticket is assigned to it" do
    result = Forefront::TicketOperations::Create.new(
      params: ActionController::Parameters.new(title: "T", description: "D", customer_id: @customer.id, category: "new_app_demo", priority: "medium"),
      current_admin: @rep
    ).call

    assert result[:success], result[:errors].inspect
    assert_equal @rep, result[:ticket].assigned_to
  end

  private

  def build_ticket(**attrs)
    Forefront::Ticket.new(title: "T", description: "D", customer: @customer, created_by: @rep, category: "new_app_demo", priority: "medium", **attrs)
  end
end
