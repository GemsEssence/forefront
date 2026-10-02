# app/queries/forefront/dashboard/period.rb
module Forefront
  module Dashboard
    # The dates a dashboard covers (?period=today|week|month|quarter|year, or
    # custom with from/to), and the period before it for comparisons.
    class Period
      LABELS = {
        "today" => "Today", "week" => "This week", "month" => "This month",
        "quarter" => "This quarter", "year" => "This year", "custom" => "Custom"
      }.freeze

      attr_reader :name, :dates

      def self.from_params(params, today: Date.current)
        name = LABELS.key?(params[:period].to_s) ? params[:period].to_s : "month"
        return new(name, calendar_unit(name, today)) unless name == "custom"

        from = parse(params[:from]) || today.beginning_of_month
        to = parse(params[:to]) || today
        from, to = to, from if from > to
        for_dates(from..to)
      end

      def self.for_dates(dates)
        new("custom", dates)
      end

      def self.calendar_unit(name, day)
        case name
        when "today" then day..day
        when "week" then day.beginning_of_week..day.end_of_week
        when "month" then day.beginning_of_month..day.end_of_month
        when "quarter" then day.beginning_of_quarter..day.end_of_quarter
        when "year" then day.beginning_of_year..day.end_of_year
        end
      end

      def self.parse(value)
        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def initialize(name, dates)
        @name = name
        @dates = dates
      end

      def times
        dates.begin.beginning_of_day..dates.end.end_of_day
      end

      # Always custom, since a named period means "the current one".
      def previous
        if name == "custom"
          length = (dates.end - dates.begin).to_i + 1
          self.class.for_dates((dates.begin - length)..(dates.begin - 1))
        else
          self.class.for_dates(self.class.calendar_unit(name, dates.begin - 1))
        end
      end

      def to_params
        return { period: name } unless name == "custom"

        { period: "custom", from: dates.begin.iso8601, to: dates.end.iso8601 }
      end

      def label
        return LABELS.fetch(name) unless name == "custom"

        "#{dates.begin.strftime("%-d %b %Y")} – #{dates.end.strftime("%-d %b %Y")}"
      end
    end
  end
end
