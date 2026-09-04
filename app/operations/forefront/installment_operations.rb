module Forefront
  module InstallmentOperations
    class Create
      attr_reader :payment, :params, :installment, :errors

      def initialize(payment:, params:)
        @payment = payment
        @params = params
        @errors = []
      end

      def call
        @installment = payment.installments.build(params.slice(:amount, :due_on))

        if @installment.save
          { success: true, installment: @installment }
        else
          @errors = @installment.errors.full_messages
          { success: false, installment: @installment, errors: @errors }
        end
      end
    end

    class MarkPaid
      attr_reader :installment, :errors

      def initialize(installment:)
        @installment = installment
        @errors = []
      end

      def call
        if installment.update(status: "paid", paid_at: Time.current)
          { success: true, installment: installment }
        else
          @errors = installment.errors.full_messages
          { success: false, installment: installment, errors: @errors }
        end
      end
    end
  end
end
