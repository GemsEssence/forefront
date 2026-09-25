require "test_helper"

class Forefront::LeadWonAtTest < ActiveSupport::TestCase
  setup do
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @admin, source: "website", status: "open")
  end

  test "won_at is set the moment status becomes won" do
    assert_nil @lead.won_at

    @lead.update!(status: "won", actual_amount: 100)

    assert_not_nil @lead.won_at
  end

  test "won_at does not change on a later, unrelated update" do
    @lead.update!(status: "won", actual_amount: 100)
    first_won_at = @lead.reload.won_at

    travel 1.hour do
      @lead.update!(description: "Updated notes")
    end

    assert_equal first_won_at.to_i, @lead.reload.won_at.to_i
  end

  test "won_at is cleared if the status is corrected away from won" do
    @lead.update!(status: "won", actual_amount: 100)
    assert_not_nil @lead.won_at

    @lead.update!(status: "negotiation")

    assert_nil @lead.reload.won_at
  end
end
