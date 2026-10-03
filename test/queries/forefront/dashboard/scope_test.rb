# test/queries/forefront/dashboard/scope_test.rb
require "test_helper"

class Forefront::Dashboard::ScopeTest < ActiveSupport::TestCase
  setup do
    @admin = staff("Asha Admin", "admin")
    @manager = staff("Mona Manager", "manager")
    @rep = staff("Ravi Rep", "sales_person", manager: @manager)
    @other_manager = staff("Omar Manager", "manager")
    @outsider = staff("Otto Outsider", "sales_person", manager: @other_manager)
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @other_product = Forefront::Product.create!(name: "Gadget")
  end

  def staff(name, role, manager: nil)
    Forefront::Admin.create!(name: name, email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
                             password: "password123", role: role, manager: manager)
  end

  def scope(viewer, **params)
    Forefront::Dashboard::Scope.from_params(viewer, ActionController::Parameters.new(params))
  end

  test "a sales person covers only themselves, whatever member is asked for" do
    assert_equal [ @rep.id ], scope(@rep).people_ids
    assert_equal [ @rep.id ], scope(@rep, member_id: @outsider.id.to_s).people_ids
  end

  test "a manager covers their team and themselves, can narrow to one, but not to an outsider" do
    assert_equal [ @manager.id, @rep.id ].sort, scope(@manager).people_ids.sort
    assert_equal [ @rep.id ], scope(@manager, member_id: @rep.id.to_s).people_ids
    assert_equal [ @manager.id, @rep.id ].sort, scope(@manager, member_id: @outsider.id.to_s).people_ids.sort
  end

  test "an admin can narrow to sales persons with no manager; nobody else can" do
    loner = staff("Lena Loner", "sales_person")
    s = scope(@admin, manager_id: "none")
    assert s.no_manager?
    assert_includes s.people_ids, loner.id
    assert_not_includes s.people_ids, @rep.id
    assert_equal "none", s.to_params[:manager_id]
    assert_not scope(@manager, manager_id: "none").no_manager?
  end

  test "a manager's own tab covers only themselves" do
    own = Forefront::Dashboard::Scope.from_params(@manager, ActionController::Parameters.new({}), own: true)
    assert_equal [ @manager.id ], own.people_ids
  end

  test "an admin covers everyone until a manager or member is picked" do
    assert_nil scope(@admin).people_ids
    assert_equal [ @other_manager.id, @outsider.id ].sort, scope(@admin, manager_id: @other_manager.id.to_s).people_ids.sort
    assert_equal [ @outsider.id ], scope(@admin, manager_id: @other_manager.id.to_s, member_id: @outsider.id.to_s).people_ids
    assert_equal [ @other_manager.id, @outsider.id ].sort, scope(@admin, manager_id: @other_manager.id.to_s, member_id: @rep.id.to_s).people_ids.sort
  end

  test "only managers and admins can pick a manager; only admins pick any product" do
    assert_nil scope(@manager, manager_id: @other_manager.id.to_s).manager_id
    assert_nil scope(@rep, product_id: @other_product.id.to_s).product_id
    assert_equal @product.id, scope(@rep, product_id: @product.id.to_s).product_id
    assert_equal @other_product.id, scope(@admin, product_id: @other_product.id.to_s).product_id
  end

  test "leads and tickets are narrowed to the people and product" do
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    mine = Forefront::Lead.create!(title: "Mine", description: "D", customer: customer, created_by: @rep, assigned_to: @rep, source: forefront_source, product: @product)
    Forefront::Lead.create!(title: "Theirs", description: "D", customer: customer, created_by: @outsider, assigned_to: @outsider, source: forefront_source)

    assert_equal [ mine ], scope(@rep).leads.to_a
    assert_equal [ mine ], scope(@admin, product_id: @product.id.to_s).leads.to_a
    assert_equal 2, scope(@admin).leads.count
  end

  test "params round-trip and describe the scope" do
    s = scope(@admin, period: "week", product_id: @product.id.to_s, manager_id: @manager.id.to_s, member_id: @rep.id.to_s)
    assert_equal({ period: "week", product_id: @product.id, manager_id: @manager.id, member_id: @rep.id }, s.to_params)
    assert_equal "This week · Widget · Ravi Rep", s.description
    assert_equal [ @rep.id ], s.previous.people_ids
    assert_equal "custom", s.previous.period.name
    assert_equal [ @rep.id ], scope(@manager).for_member(@rep).people_ids
  end
end
