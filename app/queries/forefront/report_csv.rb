require "csv"

module Forefront
  # A report's table as CSV: same columns and rows; money as plain numbers.
  class ReportCsv
    def initialize(report)
      @report = report
    end

    def call
      CSV.generate do |csv|
        csv << @report.columns.map(&:title)
        @report.rows.each { |row| csv << row.zip(@report.columns).map { |value, column| plain(value, column.format) } }
      end
    end

    private

    # A cell a spreadsheet would run as a formula gets a leading quote.
    def safe_text(text)
      text.match?(/\A[=+\-@\t\r]/) ? "'#{text}" : text
    end

    # The same rounding (half up) as the table's number helpers, so 12.5% is 13 in both.
    def rounded(value, precision)
      ActiveSupport::NumberHelper.number_to_rounded(value, precision: precision)
    end

    def plain(value, kind)
      return "" if value.nil?

      case kind
      when :money, :decimal then rounded(value, 2)
      when :percent then rounded(value, 0)
      when :days, :hours, :ratio then rounded(value, 1)
      when :date then value.to_date.iso8601
      else value.is_a?(String) ? safe_text(value) : value.to_s
      end
    end
  end
end
