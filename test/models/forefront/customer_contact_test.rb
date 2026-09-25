require "test_helper"

class Forefront::CustomerContactTest < ActiveSupport::TestCase
  test "a customer with only an email is valid" do
    assert Forefront::Customer.new(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com").valid?
  end

  test "a customer with only a phone number is valid" do
    assert Forefront::Customer.new(name: "Acme", phone: "+91 98765 43210").valid?
  end

  test "a customer needs at least an email or a phone number" do
    customer = Forefront::Customer.new(name: "Acme", email: "", phone: " ")

    assert_not customer.valid?
    assert_includes customer.errors[:base], "Provide an email or a phone number"
  end

  test "several customers without an email can be saved" do
    Forefront::Customer.create!(name: "One", email: "", phone: "5550101")
    Forefront::Customer.create!(name: "Two", email: "", phone: "5550102")

    assert_equal 2, Forefront::Customer.where(name: %w[One Two], email: nil).count
  end

  test "email must still be unique when given" do
    email = "dup-#{SecureRandom.hex(4)}@example.com"
    Forefront::Customer.create!(name: "One", email: email)

    assert_not Forefront::Customer.new(name: "Two", email: email).valid?
  end
end
