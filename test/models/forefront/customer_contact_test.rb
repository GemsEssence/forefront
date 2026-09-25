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

  test "rejects malformed email addresses" do
    [ "plainaddress", "abc@abc", "a b@example.com", "a@@example.com", "a@example." ].each do |email|
      customer = Forefront::Customer.new(name: "Acme", email: email)
      assert_not customer.valid?, "#{email.inspect} should be rejected"
      assert customer.errors[:email].any?, "#{email.inspect} should have an email error"
    end
  end

  test "accepts well-formed email addresses" do
    [ "sam@example.com", "sam.lee+crm@mail.example.co.in" ].each do |email|
      assert Forefront::Customer.new(name: "Acme", email: email).valid?, "#{email.inspect} should be accepted"
    end
  end

  test "rejects malformed phone numbers" do
    [ "abc", "12345", "555-CALL-NOW", "1234567890123456", "++91 98765 43210" ].each do |phone|
      customer = Forefront::Customer.new(name: "Acme", phone: phone)
      assert_not customer.valid?, "#{phone.inspect} should be rejected"
      assert customer.errors[:phone].any?, "#{phone.inspect} should have a phone error"
    end
  end

  test "accepts common phone number formats" do
    [ "5550100", "555-0100", "+91 98765 43210", "(555) 010-0199", "+1.555.010.0199" ].each do |phone|
      assert Forefront::Customer.new(name: "Acme", phone: phone).valid?, "#{phone.inspect} should be accepted"
    end
  end
end
