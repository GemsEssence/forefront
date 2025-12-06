module Forefront
  module LeadOperations
    class Create
      attr_reader :params, :current_admin, :lead, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @lead = Lead.new(lead_params)
        @lead.created_by = current_admin
        @lead.assigned_to_id ||= current_admin.id if params[:assigned_to_id].blank?

        if @lead.save
          { success: true, lead: @lead }
        else
          @errors = @lead.errors.full_messages
          { success: false, errors: @errors, lead: @lead }
        end
      end

      private

      def lead_params
        params.permit(
          :title, :description, :customer_id, :assigned_to_id,
          :source, :status, :due_at, :next_followup_at
        )
      end
    end

    class Update
      attr_reader :lead, :params, :current_admin, :errors

      def initialize(lead:, params:, current_admin:)
        @lead = lead
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @lead.update(lead_params)
          { success: true, lead: @lead }
        else
          @errors = @lead.errors.full_messages
          { success: false, errors: @errors, lead: @lead }
        end
      end

      private

      def lead_params
        params.permit(
          :title, :description, :customer_id, :assigned_to_id,
          :source, :status, :due_at, :next_followup_at
        )
      end
    end

    class Destroy
      attr_reader :lead, :errors

      def initialize(lead:)
        @lead = lead
        @errors = []
      end

      def call
        if @lead.destroy
          { success: true }
        else
          @errors = @lead.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end

