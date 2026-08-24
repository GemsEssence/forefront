module Forefront
  class Target < ApplicationRecord
    belongs_to :admin, class_name: "Forefront::Admin"
    belongs_to :product, class_name: "Forefront::Product"

    enum :metric, { amount: "amount", lead_count: "lead_count" }
    enum :period, { monthly: "monthly", quarterly: "quarterly", half_yearly: "half_yearly", yearly: "yearly" }

    validates :goal_value, presence: true, numericality: { greater_than: 0 }
    validates :starts_on, presence: true
    validate :starts_on_is_calendar_aligned

    def ends_on
      case period
      when "monthly" then starts_on.end_of_month
      when "quarterly" then (starts_on + 2.months).end_of_month
      when "half_yearly" then (starts_on + 5.months).end_of_month
      when "yearly" then starts_on.end_of_year
      end
    end

    def achieved_value
      won_leads = product.leads.won.where(assigned_to_id: admin_id, won_at: starts_on.beginning_of_day..ends_on.end_of_day)
      lead_count? ? won_leads.count : won_leads.count * product.price
    end

    def achieved?
      achieved_value >= goal_value
    end

    def progress_percentage
      return 0 if goal_value.zero?

      [ (achieved_value / goal_value * 100).round, 100 ].min
    end

    private

    def starts_on_is_calendar_aligned
      return if starts_on.blank? || period.blank?

      case period
      when "monthly"
        errors.add(:starts_on, "must be the first day of the month for a monthly target") unless starts_on == starts_on.beginning_of_month
      when "quarterly"
        errors.add(:starts_on, "must be the first day of a calendar quarter (Jan, Apr, Jul, Oct) for a quarterly target") unless starts_on == starts_on.beginning_of_quarter
      when "half_yearly"
        aligned = [ 1, 7 ].include?(starts_on.month) && starts_on == starts_on.beginning_of_month
        errors.add(:starts_on, "must be January 1 or July 1 for a half-yearly target") unless aligned
      when "yearly"
        errors.add(:starts_on, "must be January 1 for a yearly target") unless starts_on == starts_on.beginning_of_year
      end
    end
  end
end
