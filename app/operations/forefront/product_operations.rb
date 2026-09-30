module Forefront
  module ProductOperations
    module AllocationNames
      private

      def allocated_names(product)
        product.admins.order(:name).pluck(:name).join(", ").presence
      end
    end

    class Create
      include AllocationNames

      attr_reader :params, :current_admin, :product, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @product = Forefront::Product.new(attributes)
        @product.admin_ids = params[:admin_ids] || []

        if @product.save
          changes = AuditEvent.creation_changes(@product, only: %w[name description])
          changes["allocated_to"] = [ nil, allocated_names(@product) ] if allocated_names(@product)
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @product, audited_changes: changes)
          { success: true, product: @product }
        else
          @errors = @product.errors.full_messages
          { success: false, product: @product, errors: @errors }
        end
      end

      private

      def attributes
        params.slice(:name, :description)
      end
    end

    class Update
      include AllocationNames

      attr_reader :product, :params, :current_admin, :errors

      def initialize(product:, params:, current_admin:)
        @product = product
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        allocated_before = allocated_names(product)
        product.admin_ids = params[:admin_ids] || []

        if product.update(attributes)
          record_update(allocated_before)
          { success: true, product: product }
        else
          @errors = product.errors.full_messages
          { success: false, product: product, errors: @errors }
        end
      end

      private

      def record_update(allocated_before)
        changes = product.saved_changes.slice("name", "description")
        allocated_after = allocated_names(product)
        changes["allocated_to"] = [ allocated_before, allocated_after ] if allocated_before != allocated_after
        return if changes.empty?

        AuditEvent.record!(actor: current_admin, action: "updated", auditable: product, audited_changes: changes)
      end

      def attributes
        params.slice(:name, :description)
      end
    end
  end
end
