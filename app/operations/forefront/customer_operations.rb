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

    # Finds a Customer by country code and phone, however the number is
    # typed, or creates them. An email that's already another Customer's is
    # left off rather than failing, and a note says so for the caller to pass on.
    class FindOrCreateByPhone
      attr_reader :params, :current_admin, :errors, :notes

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
        @notes = []
      end

      def call
        customer = Customer.find_by(country_code: country_code, phone: Customer.national_number(params[:phone], country_code: country_code)) || create
        { success: errors.empty?, customer: customer, errors: errors, notes: notes }
      end

      private

      def country_code
        params[:country_code].presence || Forefront::Settings.current.default_country_code
      end

      def create
        email = params[:email].presence
        if email && Customer.exists?(email: email)
          @notes << "#{email} is already on another customer, so it wasn't saved on this one."
          email = nil
        end

        attributes = { name: params[:name], country_code: country_code, phone: params[:phone], email: email }
        result = Create.new(params: ActionController::Parameters.new(attributes), current_admin: current_admin).call
        @errors = result[:errors] unless result[:success]
        result[:customer] if result[:success]
      end
    end

    class Update
      attr_reader :customer, :params, :current_admin, :errors

      # keep_blank_contact_details: Staff who can't see a Customer's contact
      # details get blank fields, so blank means "leave it", not "clear it".
      def initialize(customer:, params:, current_admin:, keep_blank_contact_details: false)
        @customer = customer
        @params = params
        @current_admin = current_admin
        @keep_blank_contact_details = keep_blank_contact_details
        @errors = []
      end

      def call
        if @customer.update(contact_safe_params)
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

      def contact_safe_params
        attributes = customer_params
        return attributes unless @keep_blank_contact_details

        attributes = attributes.except(:email) if attributes[:email].blank?
        attributes = attributes.except(:phone, :country_code) if attributes[:phone].blank?
        attributes
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
