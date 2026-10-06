module Forefront
  # Money actually received from a Customer against a Payment or one of its
  # Installments (CONTEXT.md). An Installment, or a Payment without any, is
  # paid once its Receipts add up to it.
  #
  # A Receipt a Product's own application reported (ADR 0008) arrives with a
  # Product and the app's own reference but no Payment: an Unattached
  # Receipt, until Staff attach it or discard it.
  class Receipt < ApplicationRecord
    PAYMENT_METHODS = {
      "upi" => "UPI", "bank_transfer" => "Bank transfer", "card" => "Card",
      "cash" => "Cash", "cheque" => "Cheque", "other" => "Other"
    }.freeze

    belongs_to :payment, class_name: "Forefront::Payment", optional: true
    belongs_to :installment, class_name: "Forefront::Installment", optional: true
    belongs_to :recorded_by, class_name: "Forefront::Admin"
    belongs_to :product, class_name: "Forefront::Product", optional: true
    belongs_to :customer, class_name: "Forefront::Customer", optional: true
    belongs_to :discarded_by, class_name: "Forefront::Admin", optional: true

    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :received_on, :payment_method, presence: true
    validates :payment_method, inclusion: { in: PAYMENT_METHODS.keys }, allow_blank: true
    validates :payment, presence: true, unless: :reported_by_app?
    validates :external_reference, presence: true, uniqueness: { scope: :product_id }, if: :reported_by_app?
    validate :against_the_right_thing
    validate :not_more_than_owed

    after_create :settle, if: :attached?

    scope :unattached, -> { where(payment_id: nil, discarded_at: nil) }

    def payment_method_name
      PAYMENT_METHODS[payment_method]
    end

    def reported_by_app?
      product_id.present?
    end

    def attached?
      payment_id.present?
    end

    def discarded?
      discarded_at.present?
    end

    # The phone number the app reported, as a person would write it.
    def reported_phone
      [ country_code, phone ].compact_blank.join(" ")
    end

    # Where this Receipt could be attached: the Payment, or each pending
    # Installment, of the Customer's won Leads for its Product (or, when no
    # Customer matched, of the given Leads) that still have money owed.
    # Each is [label, "payment:ID" or "installment:ID", still owed].
    def attachable_targets(leads)
      leads = customer ? customer.leads : leads
      leads.won.where(product_id: product_id).joins(:payment).includes(:customer, payment: :installments).order(:won_at).flat_map do |lead|
        payment = lead.payment
        next [] if payment.fully_paid?

        if payment.installments.any?
          payment.installments.pending.order(:due_on).map do |installment|
            [ "#{lead.customer.name} · #{lead.title} · installment due #{installment.due_on.strftime("%-d %b %Y")}", "installment:#{installment.id}", installment.still_owed ]
          end
        else
          [ [ "#{lead.customer.name} · #{lead.title}", "payment:#{payment.id}", payment.still_owed ] ]
        end
      end
    end

    # Marks the Installment and Payment paid once their Receipts cover them.
    def settle
      installment.update!(status: "paid", paid_at: Time.current) if installment&.still_owed&.zero?
      payment.update!(status: "paid", paid_at: Time.current) if payment.reload.settled?
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
  end
end
