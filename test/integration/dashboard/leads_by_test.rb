require "test_helper"

class Forefront::Dashboard::LeadsByTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @manager = dashboard_staff("Mona Manager", "manager")
    @rep = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def lead(source, **attributes)
    Forefront::Lead.create!({ title: "L", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: source }.merge(attributes))
  end

  test "leads by stage on the team dashboard" do
    lead(forefront_source, status: "demo")
    sign_in_as(@manager)

    get "/forefront/"

    assert_equal "1", css_select(widget("leads_by_stage"), "[data-metric='pipeline'][data-slice='demo']").first.text.squish
  end

  test "leads created in the period by source, with conversion rate and revenue; the admin's is called Source ROI" do
    web = forefront_source("Website")
    lead(web)
    lead(web, status: "won", actual_amount: 4_000)
    lead(web, created_at: 60.days.ago)
    sign_in_as(@admin)

    get "/forefront/"

    roi = widget("source_roi")
    assert_equal "2", css_select(roi, "[data-metric='source_leads'][data-slice='#{web.id}']").first.text.squish
    assert_equal "1", css_select(roi, "[data-metric='source_won'][data-slice='#{web.id}']:not([data-sum])").first.text.squish
    assert_match "50%", roi.text
    assert_match "₹4,000.00", roi.text
  end
end
