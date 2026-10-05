require "test_helper"

class Forefront::Reports::RevenueTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  setup do
    @admin = dashboard_staff("Asha Admin", "admin")
    @ravi = dashboard_staff("Ravi Rep", "sales_person")
    @widget = Forefront::Product.create!(name: "Widget")
    @widget.admins << @ravi
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def won(product, amount, with_installment: false, received_on: Date.current, source: forefront_source)
    lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: @ravi, assigned_to: @ravi, source: source,
                                   product: product, status: "won", actual_amount: amount)
    payment = Forefront::Payment.create!(lead: lead, total_amount: amount)
    installment = payment.installments.create!(amount: amount, due_on: received_on) if with_installment
    Forefront::Receipt.create!(payment: payment, installment: installment, amount: amount, received_on: received_on, payment_method: "cash", recorded_by: @ravi)
  end

  def report_rows
    css_select("table[data-report] tbody tr").to_h { |row| cells = css_select(row, "td").map { |cell| cell.text.squish }; [ cells[0], cells[1..] ] }
  end

  test "receipts per product, one-off and instalment, plus a No product row" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      won(@widget, 1_000)
      won(@widget, 2_000, with_installment: true)
      won(nil, 500)
      sign_in_as(@admin)

      get "/forefront/reports/revenue"

      rows = report_rows
      assert_equal [ "₹1,000.00", "₹2,000.00", "₹3,000.00" ], rows["Widget"]
      assert_equal [ "₹500.00", "₹0.00", "₹500.00" ], rows["No product"]
    end
  end

  test "only receipts dated inside the period count" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      won(@widget, 700, received_on: Date.new(2026, 9, 30))
      won(@widget, 300, received_on: Date.new(2026, 10, 1))
      sign_in_as(@admin)

      get "/forefront/reports/revenue", params: { period: "custom", from: "2026-10-01", to: "2026-10-31" }

      assert_equal [ "₹300.00", "₹0.00", "₹300.00" ], report_rows["Widget"]
    end
  end

  test "the Source filter keeps only receipts on that source's leads" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      ads = forefront_source("Ads")
      won(@widget, 1_000)
      won(@widget, 400, source: ads)
      sign_in_as(@admin)

      get "/forefront/reports/revenue", params: { source_id: ads.id }

      assert_equal [ "₹400.00", "₹0.00", "₹400.00" ], report_rows["Widget"]
    end
  end

  test "breakdown by week puts each receipt in its week and totals them" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      won(@widget, 1_000, received_on: Date.new(2026, 10, 2))
      won(@widget, 2_000, with_installment: true, received_on: Date.new(2026, 10, 9))
      sign_in_as(@admin)

      get "/forefront/reports/revenue", params: { breakdown: "week", period: "custom", from: "2026-10-01", to: "2026-10-31" }

      headers = css_select("table[data-report] thead th").map { |th| th.text.squish }
      widget = [ "Widget", *report_rows["Widget"] ]
      assert_equal "₹1,000.00", widget[headers.index("Total · 28 Sep – 4 Oct")]
      assert_equal "₹2,000.00", widget[headers.index("Total · 5 Oct – 11 Oct")]
      assert_equal "₹0.00", widget[headers.index("Instalments · 28 Sep – 4 Oct")]
      assert_equal "₹2,000.00", widget[headers.index("Instalments · 5 Oct – 11 Oct")]
      assert_equal "₹3,000.00", widget[headers.index("Total · Total")]
    end
  end

  test "a manager sees only their team's receipts" do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      manager = dashboard_staff("Mona Manager", "manager")
      @ravi.update!(manager: manager)
      won(@widget, 1_000)
      other = dashboard_staff("Omar Other", "sales_person")
      @widget.admins << other
      lead = Forefront::Lead.create!(title: "L", description: "D", customer: @customer, created_by: other, assigned_to: other, source: forefront_source,
                                     product: @widget, status: "won", actual_amount: 900)
      payment = Forefront::Payment.create!(lead: lead, total_amount: 900)
      Forefront::Receipt.create!(payment: payment, amount: 900, received_on: Date.current, payment_method: "cash", recorded_by: other)
      sign_in_as(manager)

      get "/forefront/reports/revenue"

      assert_equal [ "₹1,000.00", "₹0.00", "₹1,000.00" ], report_rows["Widget"]
    end
  end

  test "a sales person can't open the report" do
    sign_in_as(@ravi)

    get "/forefront/reports/revenue"

    assert_redirected_to "/forefront/"
  end
end

class Forefront::Reports::RevenueQueryCountTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers

  def queries_for(path, params)
    ActiveRecord::Base.connection.clear_query_cache
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path, params: params }
    assert_response :success
    count
  end

  test "the number of queries does not grow with the products or the buckets" do
    admin = dashboard_staff("Asha Admin", "admin")
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    make = lambda do |name|
      lead = Forefront::Lead.create!(title: "L", description: "D", customer: customer, created_by: admin, assigned_to: admin, source: forefront_source,
                                     product: Forefront::Product.create!(name: name), status: "won", actual_amount: 100)
      payment = Forefront::Payment.create!(lead: lead, total_amount: 100)
      Forefront::Receipt.create!(payment: payment, amount: 100, received_on: 3.days.ago.to_date, payment_method: "cash", recorded_by: admin)
    end
    make.call("P1")
    sign_in_as(admin)
    few = queries_for("/forefront/reports/revenue", { breakdown: "day", period: "custom", from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 })
    5.times { |i| make.call("Extra #{i}") }
    many = queries_for("/forefront/reports/revenue", { breakdown: "day", period: "custom", from: 30.days.ago.to_date.iso8601, to: Date.current.iso8601 })
    assert_operator (many - few).abs, :<=, 2
  end
end
