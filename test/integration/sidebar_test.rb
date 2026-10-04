require "test_helper"

class Forefront::SidebarTest < ActionDispatch::IntegrationTest
  def sign_in_as(admin, password: "password123")
    delete "/forefront/admins/sign_out"
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: password } }
  end

  def staff(role)
    Forefront::Admin.create!(name: "#{role.humanize} Person", email: "#{role}-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
  end

  # { "Sales" => ["Leads", ...], ... } as the sidebar shows it.
  def sidebar_groups
    css_select("aside[data-sidebar] [data-nav-group]").to_h do |group|
      [ group["data-nav-group"], css_select(group, "a").map { |link| link.text.squish.sub(/ \d+\z/, "") } ]
    end
  end

  test "a sales person sees their work, sales and marketing menus, but not team or admin ones" do
    sign_in_as(staff("sales_person"))

    get "/forefront/"

    assert_equal({ "main" => [ "Dashboard", "My work", "My performance", "Reports", "Notifications" ],
                   "Sales" => [ "Leads", "Tickets", "Unassigned", "Customers" ],
                   "Marketing" => [ "Campaigns", "Products", "Targets" ] }, sidebar_groups)
  end

  test "a manager also sees the Team menu" do
    sign_in_as(staff("manager"))

    get "/forefront/"

    assert_equal [ "Dashboard", "My work", "Reports", "Notifications" ], sidebar_groups["main"]
    assert_equal [ "Staff", "Performance", "Audit log" ], sidebar_groups["Team"]
    assert_nil sidebar_groups["Admin"]
  end

  test "an admin sees the Admin menu, but no My work" do
    sign_in_as(staff("admin"))

    get "/forefront/"

    assert_equal [ "Dashboard", "Reports", "Notifications" ], sidebar_groups["main"]
    assert_equal [ "Staff", "Performance", "Audit log" ], sidebar_groups["Team"]
    assert_equal [ "Sources", "Lost reasons", "Settings" ], sidebar_groups["Admin"]
  end

  test "the menu has left the top bar, which keeps only the name" do
    sign_in_as(staff("admin"))

    get "/forefront/"

    assert_select "header a", count: 1, text: "Forefront"
  end

  test "the page you're on is highlighted, and only that one" do
    sign_in_as(staff("sales_person"))

    get "/forefront/leads"

    assert_select "aside[data-sidebar] a[aria-current='page']", count: 1, text: "Leads"
  end

  test "profile and sign out sit at the foot of the sidebar" do
    admin = staff("sales_person")
    sign_in_as(admin)

    get "/forefront/"

    assert_select "aside[data-sidebar] [data-sidebar-account]", text: /#{admin.name}/
    assert_select "aside[data-sidebar] [data-sidebar-account] a[href='/forefront/admins/edit']", text: "Edit profile"
    assert_select "aside[data-sidebar] [data-sidebar-account] form[action='/forefront/admins/sign_out']"
  end

  test "the Devise pages you see signed in show it too" do
    sign_in_as(staff("sales_person"))

    get "/forefront/admins/edit"

    assert_response :success
    assert_select "aside[data-sidebar] a[aria-current='page']", text: "Edit profile", count: 0
    assert_select "aside[data-sidebar] [data-nav-group='Sales']"
  end

  test "the header and the sidebar stay put while the page scrolls; only the menu list scrolls" do
    sign_in_as(staff("admin"))

    get "/forefront/"

    assert_select "header.sticky.top-0"
    assert_select "aside[data-sidebar].lg\\:sticky"
    assert_select "aside[data-sidebar] > nav.overflow-y-auto"
    assert_select "aside[data-sidebar] > nav [data-sidebar-account]", count: 0
  end
end
