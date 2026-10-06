require "test_helper"
require "rake"
require "minitest/mock"

# The daily Expiry pull (CONTEXT.md, ADR 0007): Forefront asks each Product's
# own application for its active subscriptions, moves Subscription expiry
# dates, and opens or resolves Renewal Tickets from them.
class Forefront::ExpiryPullTest < ActionDispatch::IntegrationTest
  # Stands in for a Product's application: pages of { phone, expires_on }.
  class FakeEndpoint
    attr_reader :pages_asked

    def initialize(*pages)
      @pages = pages
      @pages_asked = []
    end

    def page(number)
      @pages_asked << number
      { "subscriptions" => @pages[number - 1] || [], "next_page" => (number + 1 if number < @pages.size) }
    end
  end

  setup do
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @rep = Forefront::Admin.create!(name: "Ravi Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: @manager)
    @product = Forefront::Product.create!(name: "Widget", renewal_reward_percentage: 10, expiry_endpoint_url: "https://widget.example/api/subscriptions", expiry_endpoint_token: "secret-token")
    @product.admins << @rep
    @today = Date.new(2026, 10, 6)
  end

  def subscriber(name, phone, expires_in:)
    customer = Forefront::Customer.create!(name: name, country_code: "+91", phone: phone)
    lead = Forefront::Lead.create!(title: "#{name} deal", description: "D", customer: customer, created_by: @rep, assigned_to: @rep, source: forefront_source,
                                   product: @product, status: "won", actual_amount: 1000, expires_at: @today + expires_in)
    Forefront::Payment.create!(lead: lead, total_amount: 1000)
    customer
  end

  def pull(*pages)
    Forefront::ExpiryOperations::Pull.new(product: @product, endpoint: FakeEndpoint.new(*pages), today: @today).call
  end

  test "a subscription expiring within the window gets its date moved and one renewal ticket, by System, for the lead's assignee" do
    acme = subscriber("Acme", "9876543210", expires_in: 40)

    result = pull([ { "phone" => "+91 98765 43210", "expires_on" => (@today + 12).iso8601 } ])

    assert_equal({ success: true, updated: 1, opened: 1, resolved: 0, skipped: 0 }, result)
    assert_equal @today + 12, acme.subscriptions.sole.expires_at
    ticket = acme.tickets.sole
    assert ticket.renewal?
    assert ticket.open?
    assert_equal [ @product, @rep, Forefront::Admin.system_actor, @today + 12 ], [ ticket.product, ticket.assigned_to, ticket.created_by, ticket.due_at ]
    assert_match "Acme", ticket.title
    assert_nil ticket.lead

    again = pull([ { "phone" => "9876543210", "expires_on" => (@today + 12).iso8601 } ])
    assert_equal({ success: true, updated: 0, opened: 0, resolved: 0, skipped: 0 }, again)
    assert_equal 1, acme.tickets.count
  end

  test "when the app shows the subscription renewed, System resolves the open renewal ticket as renewed, which pays the reward" do
    acme = subscriber("Acme", "9876543210", expires_in: 10)
    ticket = Forefront::Ticket.create!(title: "Renew Acme", description: "D", customer: acme, product: @product, created_by: Forefront::Admin.system_actor,
                                       assigned_to: @rep, category: "renewal", priority: "medium", status: "open")

    result = pull([ { "phone" => "9876543210", "expires_on" => (@today + 375).iso8601 } ])

    assert_equal({ success: true, updated: 1, opened: 0, resolved: 1, skipped: 0 }, result)
    ticket.reload
    assert ticket.resolved?
    assert ticket.renewed?
    assert_equal 100, ticket.renewal_reward_amount
    assert_equal Forefront::Admin.system_actor, ticket.status_histories.order(:created_at).last.changed_by
    assert_equal @today + 375, acme.subscriptions.sole.expires_at
  end

  test "an unknown phone, or a customer with no subscription for the product, is counted and skipped, never created" do
    Forefront::Customer.create!(name: "Globex", country_code: "+91", phone: "5550199")

    result = pull([ { "phone" => "1111122222", "expires_on" => (@today + 5).iso8601 }, { "phone" => "5550199", "expires_on" => (@today + 5).iso8601 } ])

    assert_equal({ success: true, updated: 0, opened: 0, resolved: 0, skipped: 2 }, result)
    assert_equal 1, Forefront::Customer.count
    assert_equal 0, Forefront::Ticket.count
    assert_equal 0, Forefront::Subscription.count
  end

  test "every page is read" do
    acme = subscriber("Acme", "9876543210", expires_in: 40)
    globex = subscriber("Globex", "5550199", expires_in: 40)

    pull([ { "phone" => "9876543210", "expires_on" => (@today + 7).iso8601 } ], [ { "phone" => "5550199", "expires_on" => (@today + 8).iso8601 } ])

    assert_equal 1, acme.tickets.count
    assert_equal 1, globex.tickets.count
  end

  test "the job pulls every product with an endpoint, and one failing endpoint doesn't stop the others" do
    acme = subscriber("Acme", "9876543210", expires_in: 40)
    gadget = Forefront::Product.create!(name: "Gadget", expiry_endpoint_url: "https://gadget.example/subs", expiry_endpoint_token: "t")
    Forefront::Product.create!(name: "No endpoint")
    broken = Object.new
    def broken.page(_number) = raise(Forefront::ExpiryOperations::Endpoint::Error, "503 from gadget.example")
    endpoints = { @product => FakeEndpoint.new([ { "phone" => "9876543210", "expires_on" => (@today + 3).iso8601 } ]), gadget => broken }
    asked = []
    fake_new = ->(product) { asked << product; endpoints.fetch(product) }

    travel_to @today.in_time_zone do
      Forefront::ExpiryOperations::Endpoint.stub(:new, fake_new) { Forefront::ExpiryPullJob.perform_now }
    end

    assert_equal [ @product, gadget ].sort_by(&:id), asked.sort_by(&:id)
    assert_equal 1, acme.tickets.count
  end

  test "the rake task runs the job" do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "forefront:pull_expiries" }
    performed = false
    Forefront::ExpiryPullJob.stub(:perform_now, -> { performed = true }) { Rake::Task["forefront:pull_expiries"].execute }

    assert performed
  end

  test "the endpoint is called with the token, page by page, and bad answers raise" do
    endpoint = Forefront::ExpiryOperations::Endpoint.new(@product)
    seen = []
    ok = Net::HTTPOK.new("1.1", "200", "OK")
    ok.instance_variable_set(:@body, '{"subscriptions":[{"phone":"1","expires_on":"2026-12-01"}],"next_page":null}')
    ok.instance_variable_set(:@read, true)
    fake_get = ->(uri, headers) { seen << [ uri.to_s, headers["Authorization"] ]; ok }

    page = Net::HTTP.stub(:get_response, fake_get) { endpoint.page(2) }

    assert_equal [ [ "https://widget.example/api/subscriptions?page=2", "Bearer secret-token" ] ], seen
    assert_equal({ "subscriptions" => [ { "phone" => "1", "expires_on" => "2026-12-01" } ], "next_page" => nil }, page)

    down = Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")
    down.instance_variable_set(:@body, "")
    down.instance_variable_set(:@read, true)
    assert_raises(Forefront::ExpiryOperations::Endpoint::Error) { Net::HTTP.stub(:get_response, ->(*) { down }) { endpoint.page(1) } }
  end
end
