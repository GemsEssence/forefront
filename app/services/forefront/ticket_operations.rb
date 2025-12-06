module Forefront
  module TicketOperations
    class Create
      attr_reader :params, :current_admin, :ticket, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @ticket = Ticket.new(ticket_params)
        @ticket.created_by = current_admin
        @ticket.assigned_to_id ||= current_admin.id if params[:assigned_to_id].blank?

        if @ticket.save
          { success: true, ticket: @ticket }
        else
          @errors = @ticket.errors.full_messages
          { success: false, errors: @errors, ticket: @ticket }
        end
      end

      private

      def ticket_params
        params.permit(
          :title, :description, :customer_id, :assigned_to_id,
          :category, :priority, :status, :due_at, :next_followup_at
        )
      end
    end

    class Update
      attr_reader :ticket, :params, :current_admin, :errors

      def initialize(ticket:, params:, current_admin:)
        @ticket = ticket
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if @ticket.update(ticket_params)
          { success: true, ticket: @ticket }
        else
          @errors = @ticket.errors.full_messages
          { success: false, errors: @errors, ticket: @ticket }
        end
      end

      private

      def ticket_params
        params.permit(
          :title, :description, :customer_id, :assigned_to_id,
          :category, :priority, :status, :due_at, :next_followup_at
        )
      end
    end

    class Destroy
      attr_reader :ticket, :errors

      def initialize(ticket:)
        @ticket = ticket
        @errors = []
      end

      def call
        if @ticket.destroy
          { success: true }
        else
          @errors = @ticket.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end

    class Filter
      attr_reader :scope, :filters

      def initialize(scope: Ticket.all, filters: {})
        @scope = scope
        @filters = filters
      end

      def call
        result = @scope

        result = result.by_category(filters[:category]) if filters[:category].present?
        result = result.by_priority(filters[:priority]) if filters[:priority].present?
        result = result.by_status(filters[:status]) if filters[:status].present?
        result = result.by_customer(filters[:customer_id]) if filters[:customer_id].present?
        result = result.by_created_by(filters[:created_by_id]) if filters[:created_by_id].present?
        result = result.by_assigned_to(filters[:assigned_to_id]) if filters[:assigned_to_id].present?
        result = result.overdue if filters[:overdue] == 'true'
        result = result.due_soon if filters[:due_soon] == 'true'
        result = result.needs_followup if filters[:needs_followup] == 'true'

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
        when 'priority'
          result = result.order(priority: :desc)
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

