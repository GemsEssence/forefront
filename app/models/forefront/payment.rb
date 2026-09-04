module Forefront
  class Payment < ApplicationRecord
    belongs_to :lead, class_name: "Forefront::Lead"
    has_many :installments, class_name: "Forefront::Installment", dependent: :destroy

    enum :status, { pending: "pending", paid: "paid" }

    validates :total_amount, presence: true, numericality: { greater_than: 0 }
    validates :lead_id, uniqueness: true
    validate :lead_is_won

    def fully_paid?
      installments.any? ? installments.all?(&:paid?) : paid?
    end

    private

    def lead_is_won
      errors.add(:lead, "must be won before a payment can be recorded") if lead && !lead.won?
    end
  end
end
