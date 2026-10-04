require "test_helper"

class Forefront::ReportsTest < ActiveSupport::TestCase
  test "every registered report has a unique key and is found by it" do
    keys = Forefront::Reports.all.map(&:key)
    assert_equal keys.uniq, keys
    assert_equal Forefront::Reports::LeadStage, Forefront::Reports.find("lead_stage")
    assert_nil Forefront::Reports.find("nope")
  end

  test "registering a key twice raises" do
    assert_raises(ArgumentError) { Forefront::Reports.register("lead_stage", "Forefront::Reports::LeadStage") }
  end
end

class Forefront::ReportsFrameworkUnitTest < ActiveSupport::TestCase
  Report = Struct.new(:columns, :rows)

  def csv_for(columns, row)
    cols = columns.map.with_index { |format, i| Forefront::Reports::Column.new(key: "c#{i}", title: "C#{i}", format: format) }
    CSV.parse(Forefront::ReportCsv.new(Report.new(cols, [ row ])).call).last
  end

  test "Context and its constants autoload on first reference" do
    assert_equal %w[day week month quarter], Forefront::Reports::BREAKDOWNS
    assert Forefront::Reports::Context.respond_to?(:from_params)
    assert_equal :text, Forefront::Reports::Column.new(key: "a", title: "A", format: :text).format
  end

  test "CSV writes percent with no decimals, money with two, and nil as blank" do
    assert_equal [ "67", "12.50", "" ], csv_for(%i[percent money days], [ 66.7, 12.5, nil ])
  end

  test "the page and the CSV agree on percent" do
    view = ActionView::Base.empty
    view.extend(Forefront::ReportsHelper)
    assert_equal "67%", view.report_cell(66.7, :percent)
  end

  test "text that a spreadsheet would run as a formula is quoted" do
    assert_equal [ "'=1+1", "'+x", "'-x", "'@x", "plain" ], csv_for(%i[text text text text text], [ "=1+1", "+x", "-x", "@x", "plain" ])
  end

  test "a negative count stays a number rather than being quoted" do
    assert_equal [ "-3" ], csv_for(%i[count], [ -3 ])
  end

  test "mean does not truncate integers" do
    base = Forefront::Reports::Base.new(nil)
    assert_equal 1.5, base.send(:mean, [ 1, 2 ])
    assert_nil base.send(:mean, [])
  end
end
