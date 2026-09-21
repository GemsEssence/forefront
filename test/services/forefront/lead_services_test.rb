require "test_helper"

class Forefront::LeadServicesFilterTest < ActiveSupport::TestCase
  setup do
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
    @open_lead = Forefront::Lead.create!(title: "Open", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "open")
    @won_lead = Forefront::Lead.create!(title: "Won", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "won")
  end

  test "filters by status when called with real controller params, whose keys are Strings, not Symbols" do
    filters = ActionController::Parameters.new(status: "Won").permit(:status)

    result = Forefront::LeadServices::Filter.new(scope: Forefront::Lead.all, filters: filters).call

    assert_equal [ @won_lead ], result.to_a
  end

  test "the active boolean-toggle filter is reached and excludes won/lost leads, given real controller params" do
    filters = ActionController::Parameters.new(active: "true").permit(:active)

    result = Forefront::LeadServices::Filter.new(scope: Forefront::Lead.all, filters: filters).call

    assert_equal [ @open_lead ], result.to_a
  end

  test "the search filter is reached and matches on title, given real controller params" do
    filters = ActionController::Parameters.new(search: "Open").permit(:search)

    result = Forefront::LeadServices::Filter.new(scope: Forefront::Lead.all, filters: filters).call

    assert_equal [ @open_lead ], result.to_a
  end

  test "the won filter matches leads whose status is the enum's capitalized stored value" do
    filters = ActionController::Parameters.new(won: "true").permit(:won)

    result = Forefront::LeadServices::Filter.new(scope: Forefront::Lead.all, filters: filters).call

    assert_equal [ @won_lead ], result.to_a
  end

  test "the lost filter matches leads whose status is the enum's capitalized stored value" do
    lost_lead = Forefront::Lead.create!(title: "Lost", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: "website", status: "lost")
    filters = ActionController::Parameters.new(lost: "true").permit(:lost)

    result = Forefront::LeadServices::Filter.new(scope: Forefront::Lead.all, filters: filters).call

    assert_equal [ lost_lead ], result.to_a
  end
end
