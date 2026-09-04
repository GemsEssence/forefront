module Forefront
  module PaymentOperations
    class Create
      attr_reader :lead, :params, :payment, :errors

      def initialize(lead:, params:)
        @lead = lead
        @params = params
        @errors = []
      end

      def call
        @payment = lead.build_payment(params.slice(:total_amount))

        if @payment.save
          { success: true, payment: @payment }
        else
          @errors = @payment.errors.full_messages
          { success: false, payment: @payment, errors: @errors }
        end
      end
    end

    class MarkPaid
      attr_reader :payment, :errors

      def initialize(payment:)
        @payment = payment
        @errors = []
      end

      def call
        if payment.update(status: "paid", paid_at: Time.current)
          { success: true, payment: payment }
        else
          @errors = payment.errors.full_messages
          { success: false, payment: payment, errors: @errors }
        end
      end
    end
  end
end
