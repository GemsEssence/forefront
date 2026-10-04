module Forefront
  module Reports
    # Splits a date range into calendar buckets (weeks Monday–Sunday), each
    # clipped to the range, labelled for column headers.
    module Buckets
      def self.for(dates, breakdown)
        return [ [ "Total", dates ] ] unless BREAKDOWNS.include?(breakdown)

        starts = []
        day = start_of(dates.begin, breakdown)
        while day <= dates.end
          starts << day
          day = next_start(day, breakdown)
        end
        starts.map do |start|
          finish = next_start(start, breakdown) - 1
          [ label(start, finish, breakdown), [ start, dates.begin ].max..[ finish, dates.end ].min ]
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
