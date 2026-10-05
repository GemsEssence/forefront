module Forefront
  module Reports
    # Splits a date range into calendar buckets (weeks Monday–Sunday), each
    # clipped to the range and labelled, for column headers, with the dates it covers.
    module Buckets
      # Most columns a breakdown may make; a longer period is broken down by a coarser unit.
      MAX = 120
      COARSER = { "day" => "week", "week" => "month", "month" => "quarter", "quarter" => nil }.freeze

      # The breakdown to use for the dates: the one asked for, or the next coarser unit
      # that fits within MAX buckets, or nil (totals only) if even quarters don't.
      def self.fit(dates, breakdown)
        unit = breakdown if BREAKDOWNS.include?(breakdown)
        unit = COARSER[unit] while unit && count(dates, unit) > MAX
        unit
      end

      # How many buckets the dates make, counted without building them.
      def self.count(dates, breakdown)
        case breakdown
        when "day" then (dates.end - dates.begin).to_i + 1
        when "week" then (start_of(dates.end, "week") - start_of(dates.begin, "week")).to_i / 7 + 1
        when "month" then month_index(dates.end) - month_index(dates.begin) + 1
        when "quarter" then month_index(dates.end) / 3 - month_index(dates.begin) / 3 + 1
        end
      end

      def self.month_index(date)
        date.year * 12 + date.month - 1
      end

      def self.for(dates, breakdown)
        return [ [ "Total", dates ] ] unless BREAKDOWNS.include?(breakdown)

        starts = []
        day = start_of(dates.begin, breakdown)
        while day <= dates.end
          starts << day
          day = next_start(day, breakdown)
        end
        starts.map do |start|
          clipped = [ start, dates.begin ].max..[ next_start(start, breakdown) - 1, dates.end ].min
          [ label(clipped.begin, clipped.end, breakdown), clipped ]
        end
      end

      def self.start_of(date, breakdown)
        case breakdown
        when "day" then date
        when "week" then date.beginning_of_week(:monday)
        when "month" then date.beginning_of_month
        when "quarter" then date.beginning_of_quarter
        end
      end

      def self.next_start(date, breakdown)
        case breakdown
        when "day" then date + 1
        when "week" then date + 7
        when "month" then date.next_month.beginning_of_month
        when "quarter" then date.beginning_of_quarter >> 3
        end
      end

      def self.label(start, finish, breakdown)
        case breakdown
        when "day" then start.strftime("%-d %b")
        when "week" then "#{start.strftime("%-d %b")} – #{finish.strftime("%-d %b")}"
        when "month" then start.strftime("%b %Y")
        when "quarter" then "Q#{(start.month - 1) / 3 + 1} #{start.year}"
        end
      end
    end
  end
end
