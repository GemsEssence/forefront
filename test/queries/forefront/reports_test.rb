require "test_helper"
require "csv"

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

  test "ratio is one decimal on the page and in the CSV" do
    view = ActionView::Base.empty
    view.extend(Forefront::ReportsHelper)
    assert_equal "2.0", view.report_cell(2, :ratio)
    assert_equal "1.5", view.report_cell(1.54, :ratio)
    assert_equal [ "2.0", "" ], csv_for(%i[ratio ratio], [ 2, nil ])
  end

  test "the CSV rounds halves up, exactly like the table" do
    view = ActionView::Base.empty
    view.extend(Forefront::ReportsHelper)
    formats = %i[percent days hours ratio money decimal]
    values = [ 12.5, 0.25, 0.25, 0.25, BigDecimal("0.125"), BigDecimal("0.125") ]
    assert_equal [ "13%", "0.3", "0.3", "0.3" ], formats.first(4).zip(values).map { |format, value| view.report_cell(value, format) }
    assert_equal "0.13", view.report_cell(BigDecimal("0.125"), :decimal)
    assert_equal [ "13", "0.3", "0.3", "0.3", "0.13", "0.13" ], csv_for(formats, values)
  end

  test "CSV numbers use a plain dot whatever the host's locale" do
    locales = I18n.available_locales
    I18n.available_locales = locales + [ :de ]
    I18n.backend.store_translations(:de, number: { format: { separator: ",", delimiter: "." } })
    I18n.with_locale(:de) do
      assert_equal [ "1234567.89", "12.5" ], csv_for(%i[money days], [ 1234567.891, 12.5 ])
    end
  ensure
    I18n.available_locales = locales
  end

  test "text that a spreadsheet would run as a formula is quoted" do
    assert_equal [ "'=1+1", "'+x", "'-x", "'@x", "plain" ], csv_for(%i[text text text text text], [ "=1+1", "+x", "-x", "@x", "plain" ])
  end

  test "text starting with a tab or carriage return is quoted too" do
    assert_equal [ "'\t=1+1", "'\r=1+1" ], csv_for(%i[text text], [ "\t=1+1", "\r=1+1" ])
  end

  test "the CSV asks the report for its columns once, not once per row" do
    calls = 0
    cols = [ Forefront::Reports::Column.new(key: "a", title: "A", format: :count) ]
    report = Report.new(nil, [ [ 1 ], [ 2 ], [ 3 ] ])
    report.define_singleton_method(:columns) { calls += 1; cols }
    Forefront::ReportCsv.new(report).call
    assert_equal 1, calls
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

class Forefront::MetricReportTest < ActiveSupport::TestCase
  class Tiny < Forefront::Reports::MetricReport
    def label_columns = [ column(:name, "Name", :text) ]
    def row_keys = [ [ [ "A" ], :a ] ]

    def metrics
      [ Forefront::Reports::Metric.new(key: :per, title: "Per", format: :count, periodic: true, value: ->(_k, ctx) { ctx.period.dates.count }),
        Forefront::Reports::Metric.new(key: :now, title: "Now", format: :count, periodic: false, value: ->(_k, _c) { 99 }) ]
    end
  end

  def context(breakdown)
    admin = Forefront::Admin.new(role: "admin")
    scope = Forefront::Dashboard::Scope.new(admin, period: Forefront::Dashboard::Period.for_dates(Date.new(2026, 10, 1)..Date.new(2026, 10, 14)))
    Forefront::Reports::Context.new(scope: scope, breakdown: breakdown)
  end

  test "without a breakdown every metric is one column" do
    report = Tiny.new(context(nil))
    assert_equal [ "Name", "Per", "Now" ], report.columns.map(&:title)
    assert_equal [ [ "A", 14, 99 ] ], report.rows
  end

  test "a breakdown gives a periodic metric bucket columns and a Total, others stay single" do
    report = Tiny.new(context("week"))
    assert_equal [ "Name", "Per · 1 Oct – 4 Oct", "Per · 5 Oct – 11 Oct", "Per · 12 Oct – 14 Oct", "Per · Total", "Now" ], report.columns.map(&:title)
    assert_equal [ [ "A", 4, 7, 3, 14, 99 ] ], report.rows
    assert_equal report.columns.size, report.rows.first.size
    assert_equal report.columns.map(&:key).uniq, report.columns.map(&:key)
  end
end
