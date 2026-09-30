require "test_helper"

class Forefront::LeadCsvExportTest < ActiveSupport::TestCase
  setup do
    @rep = Forefront::Admin.create!(name: "Rep", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123", role: "sales_person")
    @product = Forefront::Product.create!(name: "Widget")
    @product.admins << @rep
    @customer = Forefront::Customer.create!(name: "Acme", email: "acme-#{SecureRandom.hex(4)}@example.com", phone: "555-0100")
  end

  test "generates a CSV with a header row and one row per lead" do
    lead = Forefront::Lead.create!(
      title: "Website revamp", description: "D", customer: @customer,
      created_by: @rep, assigned_to: @rep, source: forefront_source, status: "open", product: @product
    )

    csv = Forefront::LeadCsvExport.new(Forefront::Lead.where(id: lead.id)).call
    rows = CSV.parse(csv)

    assert_equal "Title", rows.first.first
    assert_equal 2, rows.size
    assert_includes rows.last, "Website revamp"
    assert_includes rows.last, "Acme"
    assert_includes rows.last, "Widget"
  end

  test "only includes leads from the given scope" do
    included = Forefront::Lead.create!(title: "In", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source, status: "open", product: @product)
    Forefront::Lead.create!(title: "Out", description: "D", customer: @customer, created_by: @rep, assigned_to: @rep, source: forefront_source, status: "open", product: @product)

    csv = Forefront::LeadCsvExport.new(Forefront::Lead.where(id: included.id)).call
    rows = CSV.parse(csv, headers: true)

    assert_equal 1, rows.size
    assert_equal "In", rows.first["Title"]
  end
end
