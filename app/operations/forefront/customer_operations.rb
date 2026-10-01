module Forefront
  module CustomerOperations
    class Create
      attr_reader :params, :current_admin, :customer, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @customer = Customer.new(customer_params)

        if @customer.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @customer)
          { success: true, customer: @customer }
        else
          @errors = @customer.errors.full_messages
          { success: false, errors: @errors, customer: @customer }
        end
      end

      private

      def customer_params
        params.permit(:name, :email, :country_code, :phone, :address, :business_name, :external_type, :external_id)
      end
    end

    class Update
      attr_reader :customer, :params, :current_admin, :errors

      def initialize(customer:, params:, current_admin:)
        @customer = customer
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @customer.update(customer_params)
          AuditEvent.record!(actor: current_admin, action: "updated", auditable: @customer) if @customer.saved_changes?
          { success: true, customer: @customer }
        else
          @errors = @customer.errors.full_messages
          { success: false, errors: @errors, customer: @customer }
        end
      end

      private

      def customer_params
        params.permit(:name, :email, :country_code, :phone, :address, :business_name, :external_type, :external_id)
      end
    end

    class Destroy
      attr_reader :customer, :current_admin, :errors

      def initialize(customer:, current_admin:)
        @customer = customer
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @customer.destroy
          AuditEvent.record!(actor: current_admin, action: "deleted", auditable: @customer, audited_changes: {})
          { success: true }
        else
          @errors = @customer.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end
