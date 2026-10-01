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
  end
end
