module Forefront
  module TargetOperations
    class Create
      attr_reader :params, :current_admin, :target, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @target = Forefront::Target.new(attributes)

        if @target.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @target)
          { success: true, target: @target }
        else
          @errors = @target.errors.full_messages
          { success: false, target: @target, errors: @errors }
        end
      end

      private

      def attributes
        params.slice(:admin_id, :product_id, :metric, :goal_value, :period, :starts_on, :reward_type, :reward_value, :bonus_type, :bonus_value)
      end
    end

    class Update
      attr_reader :target, :params, :current_admin, :errors

      def initialize(target:, params:, current_admin:)
        @target = target
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if target.update(attributes)
          AuditEvent.record!(actor: current_admin, action: "updated", auditable: target) if target.saved_changes?
          { success: true, target: target }
        else
          @errors = target.errors.full_messages
          { success: false, target: target, errors: @errors }
        end
      end

      private

      def attributes
        params.slice(:admin_id, :product_id, :metric, :goal_value, :period, :starts_on, :reward_type, :reward_value, :bonus_type, :bonus_value)
      end
    end
  end
end
