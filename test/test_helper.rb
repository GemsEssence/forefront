# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

class ActiveSupport::TestCase
  # Leads need a Source; most tests don't care which.
  def forefront_source(name = "Website")
    Forefront::Source.find_or_create_by!(name: name)
  end
end

# For the role dashboards: read the numbers off the page and the records
# behind them, the way the browser sees them.
module DashboardTestHelpers
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  def dashboard_staff(name, role, manager: nil)
    Forefront::Admin.create!(name: name, email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
                             password: "password123", role: role, manager: manager)
  end

  # The number a metric shows on the page just fetched (outside per-person rows unless member: is given).
  def metric(key, slice: nil, member: nil)
    selector = +"[data-metric='#{key}']"
    selector << "[data-slice='#{slice}']" if slice
    selector << (member ? "[data-member='#{member.id}']" : ":not([data-member])")
    css_select(selector).first&.text&.squish
  end

  # The rows listed behind a metric.
  def drill(key, **params)
    get "/forefront/dashboard/metrics/#{key}", params: params
    css_select("table[data-records] tbody tr").map { |row| row.text.squish }
  end

  def widget(title)
    css_select("section[data-widget='#{title}']").first
  end
end
