require "test_helper"

class Forefront::Performance::TrendTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @otto = dashboard_staff("Otto Outsider", "sales_person")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    lead = Forefront::Lead.create!(title: "Deal", description: "D", customer: customer, created_by: @ravi, assigned_to: @ravi,
                                   source: forefront_source, status: "demo")
    Forefront::StatusHistory.create!(trackable: lead, old_status: "Contacted", new_status: "Demo", changed_by: @ravi, created_at: 1.month.ago)
  end

  test "twelve months, oldest first, each month's own numbers" do
    sign_in_as(@manager)

    get "/forefront/performance/#{@ravi.id}/trend"

    assert_response :success
    labels = row_labels
    assert_equal 12, labels.size
    assert_equal Date.current.strftime("%b %Y"), labels.last
    assert_equal "1", cell(Date.current.prev_month.strftime("%b %Y"), "demos_done")
    assert_equal "0", cell(Date.current.strftime("%b %Y"), "demos_done")
    assert_select "td[data-column='overdue_now']", count: 0
  end

  test "the trend page works in a host that raises on unpermitted parameters" do
    sign_in_as(@manager)
    original = ActionController::Parameters.action_on_unpermitted_parameters
    ActionController::Parameters.action_on_unpermitted_parameters = :raise

    get "/forefront/performance/#{@ravi.id}/trend", params: { product_id: "", utm: "x" }

    assert_response :success
    assert_equal 12, row_labels.size
  ensure
    ActionController::Parameters.action_on_unpermitted_parameters = original
  end

  test "a sales person sees their own trend, and nobody sees a trend outside their scope" do
    sign_in_as(@ravi)
    get "/forefront/performance/#{@ravi.id}/trend"
    assert_response :success

    get "/forefront/performance/#{@otto.id}/trend"
    assert_response :not_found

    sign_in_as(@manager)
    get "/forefront/performance/#{@otto.id}/trend"
    assert_response :not_found
  end

  test "an Admin cannot open another Admin's trend" do
    admin = dashboard_staff("Ada Admin", "admin")
    other = dashboard_staff("Abe Admin", "admin")
    sign_in_as(admin)

    get "/forefront/performance/#{other.id}/trend"

    assert_response :not_found
  end

  test "names on the ranking open their trend" do
    sign_in_as(@manager)

    get "/forefront/performance"

    assert_select "tr[data-row='Ravi Rep'] a[href='/forefront/performance/#{@ravi.id}/trend']"
  end

  test "the name link carries the product filter into the trend" do
    product = Forefront::Product.create!(name: "Widget")
    product.admins << @ravi
    sign_in_as(@manager)

    get "/forefront/performance", params: { product_id: product.id }

    assert_select "tr[data-row='Ravi Rep'] a[href='/forefront/performance/#{@ravi.id}/trend?product_id=#{product.id}']"
  end
end
