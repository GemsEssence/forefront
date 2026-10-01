module Forefront
  # Money actually received from a Customer against a Payment or one of its
  # Installments (CONTEXT.md). An Installment, or a Payment without any, is
  # paid once its Receipts add up to it.
  class Receipt < ApplicationRecord
    PAYMENT_METHODS = {
      "upi" => "UPI", "bank_transfer" => "Bank transfer", "card" => "Card",
      "cash" => "Cash", "cheque" => "Cheque", "other" => "Other"
    }.freeze

    belongs_to :payment, class_name: "Forefront::Payment"
    belongs_to :installment, class_name: "Forefront::Installment", optional: true
    belongs_to :recorded_by, class_name: "Forefront::Admin"

    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :received_on, :payment_method, presence: true
    validates :payment_method, inclusion: { in: PAYMENT_METHODS.keys }, allow_blank: true
    validate :against_the_right_thing
    validate :not_more_than_owed

    after_create :settle

    def payment_method_name
      PAYMENT_METHODS[payment_method]
    end

    private

    def owed_by
      installment || payment
    end

    def against_the_right_thing
      return if payment.nil?

      if installment.nil? && payment.installments.any?
        errors.add(:installment, "must be chosen")
      elsif installment && installment.payment_id != payment_id
        errors.add(:installment, "isn't part of this payment")
      end
    end

    def not_more_than_owed
      return if amount.blank? || errors[:installment].any? || payment.nil?

      owed = owed_by.still_owed
      return if amount <= owed

      errors.add(:amount, "is more than the #{ActiveSupport::NumberHelper.number_to_rounded(owed, precision: 2, delimiter: ",")} still owed")
    end

    def settle
      installment.update!(status: "paid", paid_at: Time.current) if installment&.still_owed&.zero?
      payment.update!(status: "paid", paid_at: Time.current) if payment.reload.settled?
    end
  end
end
