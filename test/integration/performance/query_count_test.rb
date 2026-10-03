require "test_helper"

# Each person (or, for Admins, each team) adds a row of sixteen figures to the
# Performance page; this keeps that cost from creeping up unnoticed.
class Forefront::Performance::QueryCountTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  PER_PERSON_BOUND = 24 # measured 19.7, plus 20%
  PER_TEAM_BOUND = 26 # measured 21.0, plus 20%

  # The test shares one connection across requests, so its query cache would
  # otherwise carry over from the previous request.
  def count_queries
    ActiveRecord::Base.connection.clear_query_cache
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    assert_response :success
    count
  end

  test "the manager's ranking grows by a bounded number of queries per extra person" do
    manager = dashboard_staff("Mona Manager", "manager")
    3.times { |index| dashboard_staff("Rep #{index}", "sales_person", manager: manager) }
    sign_in_as(manager)
    small = count_queries { get "/forefront/performance" }
    3.times { |index| dashboard_staff("More #{index}", "sales_person", manager: manager) }
    large = count_queries { get "/forefront/performance" }

    per_person = (large - small) / 3.0
    puts "\nPerformance (manager): 3 people=#{small}, 6 people=#{large}, #{per_person} per person" if ENV["SHOW_QUERY_COUNT"]
    assert per_person <= PER_PERSON_BOUND, "#{per_person} queries per extra person (#{small} → #{large})"
  end

  test "the admin's team view grows by a bounded number of queries per extra team" do
    add_team = lambda do |index|
      manager = dashboard_staff("Manager #{index}", "manager")
      2.times { |rep| dashboard_staff("Rep #{index}-#{rep}", "sales_person", manager: manager) }
    end
    admin = dashboard_staff("Asha Admin", "admin")
    2.times { |index| add_team.call(index) }
    sign_in_as(admin)
    small = count_queries { get "/forefront/performance" }
    2.times { |index| add_team.call(index + 2) }
    large = count_queries { get "/forefront/performance" }

    per_team = (large - small) / 2.0
    puts "\nPerformance (admin): 2 teams=#{small}, 4 teams=#{large}, #{per_team} per team" if ENV["SHOW_QUERY_COUNT"]
    assert per_team <= PER_TEAM_BOUND, "#{per_team} queries per extra team (#{small} → #{large})"
  end
end
