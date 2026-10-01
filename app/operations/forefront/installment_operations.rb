module Forefront
  module InstallmentOperations
    class Create
      attr_reader :payment, :params, :current_admin, :installment, :errors

      def initialize(payment:, params:, current_admin:)
        @payment = payment
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @installment = payment.installments.build(params.slice(:amount, :due_on))

        if @installment.save
          AuditEvent.record!(actor: current_admin, action: "added_installment", auditable: payment.lead,
                             audited_changes: AuditEvent.creation_changes(@installment, only: %w[amount due_on]))
          { success: true, installment: @installment }
        else
          @errors = @installment.errors.full_messages
          { success: false, installment: @installment, errors: @errors }
        end
      end
    end
  end
end
