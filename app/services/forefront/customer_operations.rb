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

    class Filter
      attr_reader :scope, :filters

      def initialize(scope: Customer.all, filters: {})
        @scope = scope
        @filters = filters
      end

      def call
        result = @scope

        result = result.by_name(filters[:name]) if filters[:name].present?
        result = result.by_email(filters[:email]) if filters[:email].present?
        result = result.by_phone(filters[:phone]) if filters[:phone].present?
        result = result.by_business_name(filters[:business_name]) if filters[:business_name].present?

        # Search
        if filters[:search].present?
          search_term = "%#{filters[:search]}%"
          result = result.where(
            "name ILIKE ? OR email ILIKE ? OR phone ILIKE ? OR business_name ILIKE ?",
            search_term, search_term, search_term, search_term
          )
        end

        # Sorting
        case filters[:sort_by]
        when 'name'
          result = result.order(:name)
        when 'email'
          result = result.order(:email)
        when 'created_at'
          result = result.order(created_at: :desc)
        else
          result = result.order(created_at: :desc)
        end

        result
      end
    end
  end
end

