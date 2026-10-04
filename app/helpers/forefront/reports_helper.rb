module Forefront
  module ReportsHelper
    def report_cell(value, kind)
      return "—" if value.nil?

      case kind
      when :money then format_money(value)
      when :count then number_with_delimiter(value)
      when :percent then number_to_percentage(value, precision: 0)
      when :days, :hours, :decimal then number_with_precision(value, precision: kind == :decimal ? 2 : 1, delimiter: ",")
      when :date then value.to_date.strftime("%-d %b %Y")
      else value.to_s
      end
    end
  end
end
