module Forefront
  module AdminOperations
    # Products are only allocated to Sales persons (Admins and Managers can
    # already sell every Product), and only when the form sent the field, so
    # saving without it leaves existing allocations alone.
    module ProductAllocation
      AUDITED_FIELDS = %w[name email role manager_id].freeze

      private

      def product_names(admin)
        admin.products.order(:name).pluck(:name).join(", ").presence
      end

      def allocate_products?(admin)
        params.key?(:product_ids) && admin.sales_person?
      end

      def product_ids
        Array(params[:product_ids]).reject(&:blank?)
      end
    end

    class Create
      include ProductAllocation

      attr_reader :params, :current_admin, :admin, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @admin = Forefront::Admin.new(base_attributes.merge(role_attributes))
        @admin.product_ids = product_ids if allocate_products?(@admin)

        if @admin.save
          changes = AuditEvent.creation_changes(@admin, only: AUDITED_FIELDS)
          changes["products"] = [ nil, product_names(@admin) ] if product_names(@admin)
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @admin, audited_changes: changes)
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
      include ProductAllocation

      attr_reader :admin, :params, :current_admin, :errors

      def initialize(admin:, params:, current_admin:)
        @admin = admin
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        products_before = product_names(admin)
        changes = {}
        saved = Forefront::Admin.transaction do
          admin.update(attributes).tap do |ok|
            changes = admin.saved_changes.slice(*AUDITED_FIELDS) if ok
            admin.product_ids = product_ids if ok && allocate_products?(admin)
          end
        end

        if saved
          record_update(changes, products_before)
          { success: true, admin: admin }
        else
          @errors = admin.errors.full_messages
          { success: false, admin: admin, errors: @errors }
        end
      end

      private

      def record_update(changes, products_before)
        changes["password"] = [ nil, "changed" ] if params[:password].present?
        products_after = product_names(admin)
        changes["products"] = [ products_before, products_after ] if products_before != products_after
        return if changes.empty?

        AuditEvent.record!(actor: current_admin, action: "updated", auditable: admin, audited_changes: changes)
      end

      def attributes
        attrs = params.slice(:name, :email)
        attrs = attrs.merge(params.slice(:password, :password_confirmation)) if params[:password].present?
        attrs = attrs.merge(params.slice(:role, :manager_id)) if current_admin.admin?
        attrs
      end
    end
  end
end
