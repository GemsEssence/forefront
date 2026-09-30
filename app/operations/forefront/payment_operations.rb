module Forefront
  module PaymentOperations
    class Create
      attr_reader :lead, :params, :current_admin, :payment, :errors

      def initialize(lead:, params:, current_admin:)
        @lead = lead
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @payment = lead.build_payment(params.slice(:total_amount))

        if @payment.save
          AuditEvent.record!(actor: current_admin, action: "recorded_payment", auditable: lead,
                             audited_changes: @payment.saved_changes.slice("total_amount"))
          { success: true, payment: @payment }
        else
          @errors = @payment.errors.full_messages
          { success: false, payment: @payment, errors: @errors }
        end
      end
    end

    class MarkPaid
      attr_reader :payment, :current_admin, :errors

      def initialize(payment:, current_admin:)
        @payment = payment
        @current_admin = current_admin
        @errors = []
      end

      def call
        if payment.update(status: "paid", paid_at: Time.current)
          AuditEvent.record!(actor: current_admin, action: "marked_payment_paid", auditable: payment.lead,
                             audited_changes: payment.saved_changes.slice("status"))
          { success: true, payment: payment }
        else
          @errors = payment.errors.full_messages
          { success: false, payment: payment, errors: @errors }
        end
      end
    end
  end
end
