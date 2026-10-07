require "test_helper"

class Forefront::Dashboard::CompanyTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @rep = dashboard_staff("Ravi Rep", "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
  end

  def subscriber(in_days)
    customer = Forefront::Customer.create!(name: "C#{in_days}", phone: "555-#{(in_days + 1000).to_s.rjust(4, '0')}")
    Forefront::Lead.create!(title: "Deal #{in_days}", description: "D", customer: customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                            product: @product, status: "won", actual_amount: 1000, expires_at: in_days.days.from_now.to_date)
  end

  test "subscriptions by product: active, expiring and expired" do
    subscriber(90)
    subscriber(10)
    subscriber(-5)
    sign_in_as(@admin)

    get "/forefront/"

    subs = widget("subscriptions")
    assert_equal "1", css_select(subs, "[data-metric='subscriptions'][data-slice='active']").first.text.squish
    assert_equal "1", css_select(subs, "[data-metric='subscriptions'][data-slice='expiring']").first.text.squish
    assert_equal "1", css_select(subs, "[data-metric='subscriptions'][data-slice='expired']").first.text.squish
  end

  test "data health counts failed signups and orphan leads" do
    Forefront::AuditEvent.record!(actor: Forefront::Admin.system_actor, action: "rejected_signup", auditable: @product,
                                  audited_changes: { "errors" => [ nil, "Phone can't be blank" ] })
    sign_in_as(@admin)

    get "/forefront/"

    health = widget("data_health")
    assert_equal "1", css_select(health, "[data-metric='failed_intake']").first.text.squish
    assert css_select(health, "[data-metric='needs_next_step']").any?
  end

  test "a manager can't open admin-only metrics" do
    sign_in_as(dashboard_staff("Mona Manager", "manager"))
    get "/forefront/dashboard/metrics/failed_intake"
    assert_redirected_to "/forefront/"
  end
end
