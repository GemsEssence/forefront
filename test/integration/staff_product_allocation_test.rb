require "test_helper"

# Products can be allocated to a Sales person from either side: the product
# form (pick sales persons) or the staff form (pick products). Both edit the
# same allocations.
class Forefront::StaffProductAllocationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Forefront::Admin.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "admin")
    @widget = Forefront::Product.create!(name: "Widget")
    @gadget = Forefront::Product.create!(name: "Gadget")
  end

  test "the staff form lists products to allocate" do
    sign_in_as(@admin)

    get "/forefront/staff/new"
    assert_select "input[type=checkbox][name='admin[product_ids][]'][value='#{@widget.id}']"
    assert_select "input[type=checkbox][name='admin[product_ids][]'][value='#{@gadget.id}']"
  end

  test "creating a sales person with products allocates them" do
    sign_in_as(@admin)

    post "/forefront/staff", params: { admin: staff_params(role: "sales_person", product_ids: [ "", @widget.id.to_s ]) }

    rep = Forefront::Admin.order(:created_at).last
    assert_redirected_to "/forefront/staff"
    assert_equal [ @widget ], rep.products.to_a
  end

  test "editing a sales person changes their products, which the product form then shows" do
    rep = create_rep(products: [ @widget ])
    sign_in_as(@admin)

    get "/forefront/staff/#{rep.id}/edit"
    assert_select "input[name='admin[product_ids][]'][value='#{@widget.id}'][checked]"
    assert_select "input[name='admin[product_ids][]'][value='#{@gadget.id}']:not([checked])"

    patch "/forefront/staff/#{rep.id}", params: { admin: { name: rep.name, email: rep.email, product_ids: [ "", @gadget.id.to_s ] } }
    assert_redirected_to "/forefront/staff"
    assert_equal [ @gadget ], rep.reload.products.to_a

    get "/forefront/products/#{@gadget.id}/edit"
    assert_select "input[name='product[admin_ids][]'][value='#{rep.id}'][checked]"
  end

  test "unticking every product removes all of a sales person's allocations" do
    rep = create_rep(products: [ @widget, @gadget ])
    sign_in_as(@admin)

    patch "/forefront/staff/#{rep.id}", params: { admin: { name: rep.name, email: rep.email, product_ids: [ "" ] } }

    assert_empty rep.reload.products
  end

  test "saving the staff form without the product field leaves allocations alone" do
    rep = create_rep(products: [ @widget ])
    sign_in_as(@admin)

    patch "/forefront/staff/#{rep.id}", params: { admin: { name: "Renamed", email: rep.email } }

    assert_equal [ @widget ], rep.reload.products.to_a
  end

  test "products aren't allocated to managers or admins, who can already sell anything" do
    sign_in_as(@admin)

    post "/forefront/staff", params: { admin: staff_params(role: "manager", product_ids: [ "", @widget.id.to_s ]) }

    assert_empty Forefront::Admin.order(:created_at).last.products
  end

  test "a manager can allocate products to their own sales person" do
    manager = Forefront::Admin.create!(name: "Max", email: "max-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "manager")
    rep = create_rep(products: [], manager: manager)
    sign_in_as(manager)

    patch "/forefront/staff/#{rep.id}", params: { admin: { name: rep.name, email: rep.email, product_ids: [ "", @widget.id.to_s ] } }

    assert_redirected_to "/forefront/staff"
    assert_equal [ @widget ], rep.reload.products.to_a
  end

  private

  def sign_in_as(admin)
    get "/forefront/admins/sign_in"
    post "/forefront/admins/sign_in", params: { admin: { email: admin.email, password: "password123" } }
  end

  def staff_params(**overrides)
    { name: "New Person", email: "new-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123" }.merge(overrides)
  end

  def create_rep(products:, manager: nil)
    rep = Forefront::Admin.create!(name: "Rita", email: "rita-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person", manager: manager)
    rep.products = products
    rep
  end
end
