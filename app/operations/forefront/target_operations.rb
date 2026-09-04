module Forefront
  module TargetOperations
    class Create
      attr_reader :params, :target, :errors

      def initialize(params:)
        @params = params
        @errors = []
      end

      def call
        @target = Forefront::Target.new(attributes)

        if @target.save
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
      attr_reader :target, :params, :errors

      def initialize(target:, params:)
        @target = target
        @params = params
        @errors = []
      end

      def call
        if target.update(attributes)
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
