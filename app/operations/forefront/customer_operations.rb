module Forefront
  module CustomerOperations
    class Create
      attr_reader :params, :customer, :errors

      def initialize(params:)
        @params = params
        @errors = []
      end

      def call
        @customer = Customer.new(customer_params)

        if @customer.save
          { success: true, customer: @customer }
        else
          @errors = @customer.errors.full_messages
          { success: false, errors: @errors, customer: @customer }
        end
      end

      private

      def customer_params
        params.permit(:name, :email, :phone, :address, :business_name)
      end
    end

    class Update
      attr_reader :customer, :params, :errors

      def initialize(customer:, params:)
        @customer = customer
        @params = params
        @errors = []
      end

      def call
        if @customer.update(customer_params)
          { success: true, customer: @customer }
        else
          @errors = @customer.errors.full_messages
          { success: false, errors: @errors, customer: @customer }
        end
      end

      private

      def customer_params
        params.permit(:name, :email, :phone, :address, :business_name)
      end
    end

    class Destroy
      attr_reader :customer, :errors

      def initialize(customer:)
        @customer = customer
        @errors = []
      end

      def call
        if @customer.destroy
          { success: true }
        else
          @errors = @customer.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end

