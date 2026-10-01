require "test_helper"

class Forefront::CustomerExternalReferenceTest < ActiveSupport::TestCase
  test "multiple customers can be unlinked (external_id blank) at the same time" do
    Forefront::Customer.create!(name: "A", email: "a-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    unlinked_two = Forefront::Customer.new(name: "B", email: "b-#{SecureRandom.hex(4)}@example.com", phone: "555-0101")

    assert unlinked_two.valid?
  end

  test "the same external_id cannot be linked twice within the same external_type" do
    Forefront::Customer.create!(name: "A", email: "a-#{SecureRandom.hex(4)}@example.com", phone: "555-0100", external_type: "User", external_id: "42")
    duplicate = Forefront::Customer.new(name: "B", email: "b-#{SecureRandom.hex(4)}@example.com", phone: "555-0100", external_type: "User", external_id: "42")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "the same external_id is fine under a different external_type" do
    Forefront::Customer.create!(name: "A", email: "a-#{SecureRandom.hex(4)}@example.com", phone: "555-0100", external_type: "User", external_id: "42")
    different_type = Forefront::Customer.new(name: "B", email: "b-#{SecureRandom.hex(4)}@example.com", phone: "555-0101", external_type: "Account", external_id: "42")

    assert different_type.valid?
  end

  test "find_by_external looks a customer up by type and id, returning nil when there's no match" do
    linked = Forefront::Customer.create!(name: "A", email: "a-#{SecureRandom.hex(4)}@example.com", phone: "555-0100", external_type: "User", external_id: "42")

    assert_equal linked, Forefront::Customer.find_by_external(external_type: "User", external_id: "42")
    assert_nil Forefront::Customer.find_by_external(external_type: "User", external_id: "no-such-id")
  end
end
