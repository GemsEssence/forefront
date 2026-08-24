module Forefront
  module AdminOperations
    class Create
      attr_reader :params, :current_admin, :admin, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @admin = Forefront::Admin.new(base_attributes.merge(role_attributes))

        if @admin.save
          { success: true, admin: @admin }
        else
          @errors = @admin.errors.full_messages
          { success: false, admin: @admin, errors: @errors }
        end
      end

      private

      def base_attributes
        params.slice(:name, :email, :password, :password_confirmation)
      end

      def role_attributes
        if current_admin.admin?
          params.slice(:role, :manager_id)
        else
          { role: "sales_person", manager_id: current_admin.id }
        end
      end
    end

    class Update
      attr_reader :admin, :params, :current_admin, :errors

      def initialize(admin:, params:, current_admin:)
        @admin = admin
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if admin.update(attributes)
          { success: true, admin: admin }
        else
          @errors = admin.errors.full_messages
          { success: false, admin: admin, errors: @errors }
        end
      end

      private

      def attributes
        attrs = params.slice(:name, :email)
        attrs = attrs.merge(params.slice(:password, :password_confirmation)) if params[:password].present?
        attrs = attrs.merge(params.slice(:role, :manager_id)) if current_admin.admin?
        attrs
      end
    end
  end
end
