require "test_helper"

class Forefront::Performance::SortingTest < ActionDispatch::IntegrationTest
  include DashboardTestHelpers
  include PerformanceTestHelpers

  setup do
    @manager = dashboard_staff("Mona Manager", "manager")
    @ravi = dashboard_staff("Ravi Rep", "sales_person", manager: @manager)
    @sara = dashboard_staff("Sara Seller", "sales_person", manager: @manager)
    customer = Forefront::Customer.create!(name: "Acme", phone: "555-0100")
    { @ravi => 1, @sara => 3 }.each do |person, demos|
      demos.times do |index|
        lead = Forefront::Lead.create!(title: "#{person.name} #{index}", description: "D", customer: customer, created_by: person,
                                       assigned_to: person, source: forefront_source, status: "demo")
        Forefront::StatusHistory.create!(trackable: lead, old_status: "Contacted", new_status: "Demo", changed_by: person)
      end
    end
  end

  test "sorts by a column, both ways, with unknown columns falling back to the default" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { sort: "demos_done", dir: "desc" }
    assert_equal [ "Sara Seller", "Ravi Rep", "Mona Manager" ], row_labels

    get "/forefront/performance", params: { sort: "demos_done", dir: "asc" }
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels

    get "/forefront/performance", params: { sort: "no_such_column", dir: "sideways" }
    assert_response :success
    assert_equal 3, row_labels.size
  end

  test "ties fall back to name order in both directions" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { sort: "followup_discipline", dir: "desc" }
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels

    get "/forefront/performance", params: { sort: "followup_discipline", dir: "asc" }
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels
  end

  test "equal values keep name order when sorting descending" do
    customer = Forefront::Customer.first
    2.times do |index|
      lead = Forefront::Lead.create!(title: "Extra #{index}", description: "D", customer: customer, created_by: @ravi,
                                     assigned_to: @ravi, source: forefront_source, status: "demo")
      Forefront::StatusHistory.create!(trackable: lead, old_status: "Contacted", new_status: "Demo", changed_by: @ravi)
    end
    sign_in_as(@manager)

    get "/forefront/performance", params: { sort: "demos_done", dir: "desc" }
    assert_equal [ "Ravi Rep", "Sara Seller", "Mona Manager" ], row_labels

    get "/forefront/performance", params: { sort: "demos_done", dir: "asc" }
    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels
  end

  test "array or junk sort params fall back to the default" do
    sign_in_as(@manager)

    get "/forefront/performance?sort[]=x&dir[]=asc"

    assert_response :success
    assert_equal 3, row_labels.size
  end

  test "a column whose values are all dashes still sorts, by name" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { sort: "avg_deal_size" }

    assert_equal [ "Mona Manager", "Ravi Rep", "Sara Seller" ], row_labels
  end

  test "headers link to sorting, toggling direction on the current column" do
    sign_in_as(@manager)

    get "/forefront/performance", params: { sort: "demos_done", dir: "desc" }

    assert_select "thead a[data-sort='demos_done'][href*='dir=asc']"
  end

  test "a Sales person sees no sort links" do
    sign_in_as(@ravi)

    get "/forefront/performance"

    assert_response :success
    assert_select "table[data-performance] tbody tr", 1
    assert_select "thead a[data-sort]", 0
  end
end
