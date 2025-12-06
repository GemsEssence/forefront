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

    class Filter
      attr_reader :scope, :filters

      def initialize(scope: Lead.all, filters: {})
        @scope = scope
        @filters = filters
      end

      def call
        result = @scope

        result = result.by_source(filters[:source]) if filters[:source].present?
        result = result.by_status(filters[:status]) if filters[:status].present?
        result = result.by_customer(filters[:customer_id]) if filters[:customer_id].present?
        result = result.by_created_by(filters[:created_by_id]) if filters[:created_by_id].present?
        result = result.by_assigned_to(filters[:assigned_to_id]) if filters[:assigned_to_id].present?
        result = result.overdue if filters[:overdue] == 'true'
        result = result.due_soon if filters[:due_soon] == 'true'
        result = result.needs_followup if filters[:needs_followup] == 'true'
        result = result.active if filters[:active] == 'true'
        result = result.won if filters[:won] == 'true'
        result = result.lost if filters[:lost] == 'true'

        # Date range filters
        if filters[:due_from].present?
          result = result.where("due_at >= ?", filters[:due_from])
        end
        if filters[:due_to].present?
          result = result.where("due_at <= ?", filters[:due_to])
        end

        # Search
        if filters[:search].present?
          search_term = "%#{filters[:search]}%"
          result = result.where("title ILIKE ? OR description ILIKE ?", search_term, search_term)
        end

        # Sorting
        case filters[:sort_by]
        when 'due_date'
          result = result.by_due_date
        when 'created_at'
          result = result.recent
        else
          result = result.recent
        end

        result
      end
    end
  end
end

