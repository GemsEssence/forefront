require "test_helper"

class Forefront::LeadOperationsTest < ActiveSupport::TestCase
  setup do
    @admin = Forefront::Admin.create!(name: "Alice", email: "alice-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "creating a lead returns success with the created, persisted lead" do
    params = ActionController::Parameters.new(
      title: "New prospect", description: "Inbound", customer_id: @customer.id, source_id: forefront_source.id, product_id: forefront_product(allocated_to: @admin).id, due_at: (Date.current + 7).iso8601
    ).permit!

    result = Forefront::LeadOperations::Create.new(params: params, current_admin: @admin, first_step: forefront_first_step).call

    assert result[:success]
    assert_instance_of Forefront::Lead, result[:lead]
    assert result[:lead].persisted?
  end
end
