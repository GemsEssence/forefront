module Forefront
  class Installment < ApplicationRecord
    REMINDER_LEAD_DAYS = 3

    belongs_to :payment, class_name: "Forefront::Payment"
    has_many :followups, as: :followupable, class_name: "Forefront::Followup", dependent: :destroy
    has_many :receipts, class_name: "Forefront::Receipt", dependent: :destroy

    enum :status, { pending: "pending", paid: "paid" }

    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :due_on, presence: true
    validate :total_does_not_exceed_payment

    after_create :schedule_reminder_followup
    after_update :complete_pending_followups, if: :saved_change_to_status_when_paid?

    def still_owed
      amount - receipts.sum(:amount)
    end

    private

    def total_does_not_exceed_payment
      return if amount.blank? || payment.blank?

      other_installments_total = payment.installments.where.not(id: id).sum(:amount)
      if other_installments_total + amount > payment.total_amount
        errors.add(:amount, "would bring the total installments above the payment's total_amount")
      end
    end

    def schedule_reminder_followup
      assignee = payment.lead.assigned_to || payment.lead.created_by

      followups.create!(
        followupable: self,
        assigned_to: assignee,
        created_by: assignee,
        followup_type: "call",
        status: "pending",
        scheduled_for: due_on - REMINDER_LEAD_DAYS.days,
        outcome: "Reminder to collect installment of #{amount} due #{due_on}"
      )
    end

    def saved_change_to_status_when_paid?
      saved_change_to_status? && paid?
    end

    def complete_pending_followups
      followups.pending.find_each { |followup| followup.update!(status: "completed", completed_at: Time.current) }
    end
  end
end
