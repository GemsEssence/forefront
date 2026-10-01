require "test_helper"

class Forefront::MyWorkTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @outsider = Forefront::Admin.create!(name: "Otto Outsider", email: "otto-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
  end

  def ticket(title, assignee: @rep, **attributes)
    Forefront::Ticket.create!({ title: title, description: "D", customer: @customer, created_by: assignee || @manager, assigned_to: assignee,
                                category: "request", priority: "medium", status: "open" }.merge(attributes))
  end

  def section(name)
    css_select("[data-section='#{name}'] li").map { |item| item.text.squish }
  end

  test "a sales person's work is sorted into overdue, today, the next 7 days and undated" do
    ticket("Late ticket", due_at: 2.days.ago.to_date)
    ticket("Today's ticket", due_at: Date.current)
    ticket("Friday's ticket", due_at: 3.days.from_now.to_date)
    ticket("Someday ticket")
    ticket("Next month's ticket", due_at: 30.days.from_now.to_date)
    ticket("Done ticket", due_at: 2.days.ago.to_date, status: "resolved")
    lead = Forefront::Lead.create!(title: "Big Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                   source: forefront_source, product: @product, status: "demo")
    lead.followups.create!(assigned_to: @rep, created_by: @rep, followup_type: "call", scheduled_for: 1.hour.ago)
    sign_in_as(@rep)

    get "/forefront/my_work"

    assert_response :success
    assert_equal 2, section("overdue").size
    assert section("overdue").any? { |item| item.include?("Late ticket") }
    assert section("overdue").any? { |item| item.include?("Followup (call) on Big Deal") }
    assert section("today").any? { |item| item.include?("Today's ticket") }
    assert section("next_7_days").any? { |item| item.include?("Friday's ticket") }
    assert section("undated").any? { |item| item.include?("Someday ticket") }
    assert section("undated").any? { |item| item.include?("Big Deal") }
    assert_not css_select("body").text.include?("Done ticket")
    assert section("later").none?
  end

  test "an installment due soon on one of their leads shows in the right section" do
    lead = Forefront::Lead.create!(title: "Won Deal", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep,
                                   source: forefront_source, product: @product, status: "won", actual_amount: 1000)
    Forefront::Payment.create!(lead: lead, total_amount: 1000).installments.create!(amount: 500, due_on: Date.current)
    sign_in_as(@rep)

    get "/forefront/my_work"

    assert section("today").any? { |item| item.include?("Installment of ₹500.00 on Won Deal") }
  end

  test "work they could take, and reveals they haven't followed up, have their own sections" do
    ticket("Free ticket", assignee: nil, product: @product)
    Forefront::ContactReveal.create!(admin: @rep, customer: @customer)
    sign_in_as(@rep)

    get "/forefront/my_work"

    assert section("available").any? { |item| item.include?("Free ticket") }
    assert section("reveals").any? { |item| item.include?("Acme") }
  end

  test "someone else's work isn't on a sales person's list" do
    ticket("Otto's ticket", assignee: @outsider, due_at: Date.current)
    sign_in_as(@rep)

    get "/forefront/my_work"

    assert_not response.body.include?("Otto's ticket")
  end

  test "a manager sees their team's work, with who it belongs to" do
    ticket("Ravi's ticket", due_at: Date.current)
    ticket("Otto's ticket", assignee: @outsider, due_at: Date.current)
    sign_in_as(@manager)

    get "/forefront/my_work"

    assert section("today").any? { |item| item.include?("Ravi's ticket") && item.include?("Ravi Rep") }
    assert_not response.body.include?("Otto's ticket")
  end

  test "the dashboard points to it with counts" do
    ticket("Late ticket", due_at: 2.days.ago.to_date)
    sign_in_as(@rep)

    get "/forefront/"

    assert_select "a[href='/forefront/my_work']", text: /My work/
    assert_select "[data-my-work-summary]", text: /1 overdue/
  end
end
