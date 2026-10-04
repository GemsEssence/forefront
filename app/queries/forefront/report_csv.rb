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
      text.match?(/\A[=+\-@]/) ? "'#{text}" : text
    end

    def plain(value, kind)
      return "" if value.nil?

      case kind
      when :money, :decimal then Kernel.format("%.2f", value)
      when :percent then Kernel.format("%.0f", value)
      when :days, :hours then Kernel.format("%.1f", value)
      when :date then value.to_date.iso8601
      else safe_text(value.to_s)
      end
    end
  end
end
