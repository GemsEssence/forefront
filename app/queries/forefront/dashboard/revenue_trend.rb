module Forefront
  module Dashboard
    # Receipts per month for the last 12 months (this one included), for the
    # people and Product in view. Grouped in Ruby so the SQL stays portable.
    class RevenueTrend
      def initialize(scope, today: Date.current)
        @scope = scope
        @first = today.beginning_of_month << 11
        @last = today.end_of_month
      end

      def months
        totals = @scope.receipts.where(received_on: @first..@last).pluck(:received_on, :amount)
                       .group_by { |on, _| on.beginning_of_month }.transform_values { |rows| rows.sum { |_, amount| amount } }
        (0..11).map { |offset| @first >> offset }.map { |month| [ month, totals.fetch(month, 0.to_d) ] }
      end
    end
  end
end
