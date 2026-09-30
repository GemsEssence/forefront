module Forefront
  class Target < ApplicationRecord
    belongs_to :admin, class_name: "Forefront::Admin"
    belongs_to :product, class_name: "Forefront::Product"

    enum :metric, { amount: "amount", lead_count: "lead_count" }
    enum :period, { monthly: "monthly", quarterly: "quarterly", half_yearly: "half_yearly", yearly: "yearly" }
    enum :reward_type, { fixed: "fixed", percentage: "percentage" }, prefix: true
    enum :bonus_type, { fixed: "fixed", percentage: "percentage" }, prefix: true

    validates :goal_value, presence: true, numericality: { greater_than: 0 }
    validates :starts_on, presence: true
    validate :starts_on_is_calendar_aligned
    validates :reward_value, presence: true, numericality: { greater_than: 0 }, if: :reward_type?
    validates :reward_value, numericality: { less_than_or_equal_to: 100 }, if: :reward_type_percentage?
    validates :bonus_value, presence: true, numericality: { greater_than: 0 }, if: :bonus_type?
    validates :bonus_value, numericality: { less_than_or_equal_to: 100 }, if: :bonus_type_percentage?

    def audit_label
      "#{admin.name} · #{product.name}"
    end

    def ends_on
      case period
      when "monthly" then starts_on.end_of_month
      when "quarterly" then (starts_on + 2.months).end_of_month
      when "half_yearly" then (starts_on + 5.months).end_of_month
      when "yearly" then starts_on.end_of_year
      end
    end

    # lead_count: this admin's share of each Lead won in the period.
    # amount: the same shares applied to each won Lead's actual amount (Leads
    # won before actual amounts were recorded add nothing).
    def achieved_value
      won_leads_in_period = product.leads.won.where(won_at: starts_on.beginning_of_day..ends_on.end_of_day)
      credited = won_leads_in_period.map { |lead| [ lead, lead.share_fraction_for(admin_id) ] }.select { |_, share| share.positive? }

      return credited.sum { |_, share| share } if lead_count?

      credited.sum { |lead, share| lead.actual_amount.to_d * share }
    end

    def achieved?
      achieved_value >= goal_value
    end

    def progress_percentage
      return 0 if goal_value.zero?

      [ (achieved_value / goal_value * 100).round, 100 ].min
    end

    def missed?
      Date.current > ends_on && !achieved?
    end

    def reward_amount
      return 0 unless achieved? && reward_type?

      reward_type_fixed? ? reward_value : (reward_value / 100.0 * goal_value)
    end

    def bonus_amount
      return 0 unless achieved_value > goal_value && bonus_type?

      bonus_type_fixed? ? bonus_value : (bonus_value / 100.0 * goal_value)
    end

    def total_payout
      reward_amount + bonus_amount
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
