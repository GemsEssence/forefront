module Forefront
  module ReceiptOperations
    class Create
      attr_reader :payment, :params, :current_admin, :receipt, :errors

      def initialize(payment:, params:, current_admin:)
        @payment = payment
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @receipt = payment.receipts.build(params.slice(:installment_id, :amount, :received_on, :payment_method, :reference).merge(recorded_by: current_admin))

        if @receipt.save
          AuditEvent.record!(actor: current_admin, action: "recorded_receipt", auditable: payment.lead,
                             audited_changes: AuditEvent.creation_changes(@receipt, only: %w[amount received_on payment_method reference]))
          { success: true, receipt: @receipt }
        else
          @errors = @receipt.errors.full_messages
          { success: false, receipt: @receipt, errors: @errors }
        end
      end
    end

    # A Product's application reporting money a Customer paid in it. The
    # app's reference makes a repeated report answer with the first Receipt.
    # The Customer is matched by phone; an unknown number is kept on the
    # Receipt for Staff to match by hand, never turned into a Customer.
    class Receive
      attr_reader :product, :params, :errors

      def initialize(product:, params:)
        @product = product
        @params = params
        @errors = []
      end

      def call
        existing = Receipt.find_by(product: product, external_reference: params[:reference].presence)
        return { success: true, status: :ok, receipt: existing } if existing

        receipt = Receipt.new(attributes)
        @errors << "Amount must be greater than 0" unless params[:amount].to_s.match?(/\A\d+(\.\d+)?\z/) && params[:amount].to_d.positive?
        @errors << "Reference can't be blank" if params[:reference].blank?
        if errors.empty? && receipt.save
          AuditEvent.record!(actor: system, action: "received_receipt", auditable: receipt,
                             audited_changes: AuditEvent.creation_changes(receipt, only: %w[amount received_on payment_method external_reference phone]))
          { success: true, status: :created, receipt: receipt }
        else
          @errors = (errors + receipt.errors.full_messages).uniq
          { success: false, errors: @errors }
        end
      end

      private

      def system
        @system ||= Admin.system_actor
      end

      def country_code
        params[:country_code].presence || Settings.current.default_country_code
      end

      def phone
        Customer.national_number(params[:phone], country_code: country_code)
      end

      def received_on
        Date.parse(params[:paid_at].to_s)
      rescue ArgumentError, TypeError
        @errors << "Paid at must be a date"
        nil
      end

      def attributes
        @errors << "Phone can't be blank" if phone.blank?
        {
          product: product, customer: Customer.find_by(country_code: country_code, phone: phone),
          country_code: country_code, phone: phone, amount: params[:amount].presence, received_on: received_on,
          payment_method: Receipt::PAYMENT_METHODS.key?(params[:method].to_s) ? params[:method] : "other",
          external_reference: params[:reference].presence, reference: params[:reference].presence, recorded_by: system
        }
      end
    end

    # Staff saying which Payment or Installment an Unattached Receipt pays.
    # The ordinary rules then apply: it can't exceed what is still owed, and
    # it settles what it covers.
    class Attach
      attr_reader :receipt, :target, :current_admin, :errors

      # "payment:12" or "installment:7", as the attach form sends it.
      def self.resolve(target)
        kind, id = target.to_s.split(":", 2)
        case kind
        when "payment" then Payment.find_by(id: id)
        when "installment" then Installment.find_by(id: id)
        end
      end

      def initialize(receipt:, target:, current_admin:)
        @receipt = receipt
        @target = target
        @current_admin = current_admin
        @errors = []
      end

      def call
        return failure("This receipt has already been dealt with") if receipt.attached? || receipt.discarded?
        return failure("Choose what the receipt pays") if target.nil?

        payment = target.is_a?(Installment) ? target.payment : target
        return failure("That payment isn't for #{receipt.product.name}") unless payment.lead.product_id == receipt.product_id

        receipt.assign_attributes(payment: payment, installment: (target if target.is_a?(Installment)), customer: receipt.customer || payment.lead.customer)
        if receipt.save
          receipt.settle
          AuditEvent.record!(actor: current_admin, action: "attached_receipt", auditable: payment.lead,
                             audited_changes: { "receipt" => [ nil, "#{receipt.external_reference} #{receipt.amount}" ] })
          { success: true, receipt: receipt }
        else
          receipt.restore_attributes
          failure(*receipt.errors.full_messages)
        end
      end

      private

      def failure(*messages)
        @errors = messages
        { success: false, errors: @errors }
      end
    end

    # A Manager or Admin setting aside a duplicate or test Receipt, with a
    # note saying why. It stays on record but leaves the unattached list.
    class Discard
      attr_reader :receipt, :note, :current_admin, :errors

      def initialize(receipt:, note:, current_admin:)
        @receipt = receipt
        @note = note.to_s.strip
        @current_admin = current_admin
        @errors = []
      end

      def call
        return { success: false, errors: (@errors = [ "Say why it's being discarded" ]) } if note.blank?
        return { success: false, errors: (@errors = [ "This receipt has already been dealt with" ]) } if receipt.attached? || receipt.discarded?

        receipt.update!(discarded_at: Time.current, discarded_by: current_admin, discard_note: note)
        AuditEvent.record!(actor: current_admin, action: "discarded_receipt", auditable: receipt, audited_changes: { "note" => [ nil, note ] })
        { success: true, receipt: receipt }
      end
    end
  end
end
