require "test_helper"

# The Company page still costs queries per person: Workload and Performance
# count 11 metrics for each row. Measured at 11.4 per extra person (12.6
# before Scope stopped re-checking each row's person); this keeps that cost
# from creeping up unnoticed.
class Forefront::Dashboard::QueryCountTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  MAX_QUERIES_PER_PERSON = 12

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @product = Forefront::Product.create!(name: "Widget")
  end

  def add_people(count)
    count.times do
      rep = dashboard_staff("Rep #{SecureRandom.hex(3)}", "sales_person", manager: @manager)
      @product.admins << rep
      customer = Forefront::Customer.create!(name: "C #{rep.name}", phone: "555-#{rand(1000..9999)}")
      lead = Forefront::Lead.create!(title: "L #{rep.name}", description: "D", customer: customer, created_by: rep, assigned_to: rep,
                                     source: forefront_source, product: @product)
      lead.assignments.create!(to_user: rep, changed_by: @manager)
      lead.followups.create!(assigned_to: rep, created_by: rep, followup_type: "call", scheduled_for: 1.hour.ago)
    end
  end

  # The test shares one connection across requests, so its query cache would
  # otherwise carry over from the previous request.
  def queries_for(path)
    ActiveRecord::Base.connection.clear_query_cache
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    assert_response :success
    count
  end

  def queries_for_company_page
    queries_for("/forefront/")
  end

  test "each extra person adds only a bounded number of queries to the Company page" do
    add_people(5)
    sign_in_as(@admin)
    with_five = queries_for_company_page

    add_people(5)
    with_ten = queries_for_company_page

    per_person = (with_ten - with_five) / 5.0
    puts "\nCompany page queries: 5 people=#{with_five}, 10 people=#{with_ten}, #{per_person} per extra person" if ENV["SHOW_QUERY_COUNT"]
    assert_operator per_person, :<=, MAX_QUERIES_PER_PERSON
  end

  test "the lists behind leads, followups and assignments load their related records up front" do
    add_people(2)
    sign_in_as(@admin)
    paths = %w[active_leads overdue_followups newly_assigned].map { |key| "/forefront/dashboard/metrics/#{key}" }
    with_two = paths.to_h { |path| [ path, queries_for(path) ] }

    add_people(4)
    with_six = paths.to_h { |path| [ path, queries_for(path) ] }

    assert_equal with_two, with_six
  end
end
