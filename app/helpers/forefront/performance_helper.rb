module Forefront
  module PerformanceHelper
    # One table cell, linked to the records behind its number.
    def performance_cell(row, column)
      content_tag :td, performance_value(row, column), class: "px-3 py-2 text-right whitespace-nowrap", data: { column: column.key }
    end

    private

    def performance_value(row, column)
      value = row.values[column.key]
      text = performance_text(value, column.format)
      return text if text == "—" || column.format == :reasons

      metric_link_with(text, column.metric, row.scope)
    end

    def performance_text(value, format)
      return "—" if value.nil?

      case format
      when :count then number_with_delimiter(value)
      when :money then format_money(value)
      when :hours then "#{number_with_precision(value, precision: 1)} h"
      when :days then "#{number_with_precision(value, precision: 1)} d"
      when :percent then number_to_percentage(value, precision: 0)
      when :rate then value.percent.nil? ? "—" : "#{value.numerator} of #{value.denominator} (#{number_to_percentage(value.percent, precision: 0)})"
      else value.to_s
      end
    end
  end
end
