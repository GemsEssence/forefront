require "test_helper"

# An Admin tells Forefront where each Product's application lists its
# subscriptions for the Expiry pull, and how far ahead renewals are opened.
class Forefront::ProductExpiryEndpointTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  setup do
    @admin = Forefront::Admin.create!(name: "Asha Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @manager = Forefront::Admin.create!(name: "Mona Manager", email: "mona-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    @product = Forefront::Product.create!(name: "Widget")
  end

  test "an admin sets the endpoint and token; the token is shown masked and a blank entry keeps it" do
    sign_in_as(@admin)
    get "/forefront/products/#{@product.id}/edit"
    assert_select "input[name='product[expiry_endpoint_url]']"
    assert_select "input[name='product[expiry_endpoint_token]'][type=password]"

    patch "/forefront/products/#{@product.id}", params: { product: { name: "Widget", expiry_endpoint_url: "https://widget.example/api/subscriptions", expiry_endpoint_token: "secret-token" } }
    assert_equal [ "https://widget.example/api/subscriptions", "secret-token" ], [ @product.reload.expiry_endpoint_url, @product.expiry_endpoint_token ]

    get "/forefront/products/#{@product.id}/edit"
    assert_no_match "secret-token", response.body
    assert_select "p", text: /Token ending …oken/

    patch "/forefront/products/#{@product.id}", params: { product: { name: "Widget", expiry_endpoint_url: "https://widget.example/api/v2/subscriptions", expiry_endpoint_token: "" } }
    assert_equal [ "https://widget.example/api/v2/subscriptions", "secret-token" ], [ @product.reload.expiry_endpoint_url, @product.expiry_endpoint_token ]
  end

  test "a manager neither sees nor changes the endpoint" do
    @product.update!(expiry_endpoint_url: "https://widget.example/api/subscriptions", expiry_endpoint_token: "secret-token")
    sign_in_as(@manager)

    get "/forefront/products/#{@product.id}/edit"
    assert_select "input[name='product[expiry_endpoint_url]']", count: 0
    assert_no_match "secret-token", response.body

    patch "/forefront/products/#{@product.id}", params: { product: { name: "Widget", expiry_endpoint_url: "https://evil.example", expiry_endpoint_token: "x" } }
    assert_equal [ "https://widget.example/api/subscriptions", "secret-token" ], [ @product.reload.expiry_endpoint_url, @product.expiry_endpoint_token ]
  end

  test "the renewal window is an admin setting, starting at 30 days" do
    sign_in_as(@admin)
    get "/forefront/settings"
    assert_select "input[name='settings[renewal_window_days]'][value='30']"

    patch "/forefront/settings", params: { settings: { renewal_window_days: "45", lead_cap: "10", unassigned_alert_after_hours: "2", stale_after_hours: "24",
                                                       reveal_action_within_minutes: "60", installment_overdue_after_days: "1", default_country_code: "+91" } }

    assert_equal 45, Forefront::Settings.current.renewal_window_days
  end
end
