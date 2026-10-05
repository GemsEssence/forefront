require "test_helper"
require_relative "../../db/migrate/20261005000001_rename_ticket_categories"

# Hosts already have "Demo" and "Plan Expired" rows; the migration moves them
# onto the names the engine now uses.
class RenameTicketCategoriesTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "A", email: "a-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    @demo = ticket("new_app_demo")
    @renewal = ticket("renewal")
    @request = ticket("request")
    Forefront::Ticket.where(id: @demo.id).update_all(category: "Demo")
    Forefront::Ticket.where(id: @renewal.id).update_all(category: "Plan Expired")
  end

  def ticket(category)
    Forefront::Ticket.create!(title: "T", description: "D", customer: @customer, created_by: @admin, category: category, priority: "medium", status: "open")
  end

  test "up renames Demo and Plan Expired rows and leaves the rest alone" do
    ActiveRecord::Migration.suppress_messages { RenameTicketCategories.new.migrate(:up) }

    assert_equal "New App Demo", @demo.reload.category_before_type_cast
    assert_equal "Renewal", @renewal.reload.category_before_type_cast
    assert_equal "Request", @request.reload.category_before_type_cast
  end

  test "down puts the old names back" do
    ActiveRecord::Migration.suppress_messages do
      RenameTicketCategories.new.migrate(:up)
      RenameTicketCategories.new.migrate(:down)
    end

    assert_equal "Demo", @demo.reload.category_before_type_cast
    assert_equal "Plan Expired", @renewal.reload.category_before_type_cast
  end
end
