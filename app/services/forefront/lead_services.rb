module Forefront
  module LeadServices
    class Filter
      attr_reader :scope, :filters

      def initialize(scope: Lead.all, filters: {})
        @scope = scope
        @filters = filters
      end

      def call
        conditions = []
        params = {}

        # Build conditions
        filters.each do |key, value|
          next if value.blank?
          case key
          when :overdue
            next if value != 'true'

            conditions << "(due_at < :current_date AND status NOT IN ('Won', 'Lost'))"
            params[:current_date] = Date.current
          when :due_soon
            next if value != 'true'

            conditions << "(due_at BETWEEN :due_from AND :due_soon_to AND status NOT IN ('Won', 'Lost'))"
            params[:due_from] = Date.current
            params[:due_soon_to] = 1.day.from_now
          when :needs_followup
            next if value != 'true'

            conditions << "(next_followup_at <= :current_time AND status NOT IN ('won', 'lost'))"
            params[:current_time] = Time.current
          when :due_from
            conditions << "due_at >= :due_from"
            params[:due_from] = value
          when :due_to
            conditions << "due_at <= :due_to"
            params[:due_to] = value
          when :search
            conditions << "(title ILIKE :search OR description ILIKE :search)"
            params[:search] = "%#{value}%"
          when :active
            next if value != 'true'
            conditions << "status NOT IN ('won', 'lost')"
          when :won
            next if value != 'true'
            conditions << "status = 'won'"
          when :lost
            next if value != 'true'
            conditions << "status = 'lost'"
          else
            conditions << "#{key} = :#{key}"
            params[key] = value
          end
        end

        # Build result with all conditions
        result = @scope
        if conditions.any?
          query_string = conditions.join(" AND ")
          result = result.where(query_string, params)
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