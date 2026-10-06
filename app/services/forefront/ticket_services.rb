module Forefront
  module TicketServices
    class Filter
      attr_reader :scope, :filters

      def initialize(scope: Ticket.all, filters: {})
        @scope = scope
        @filters = filters
      end

      def call
        like = Forefront::ApplicationRecord.case_insensitive_like
        conditions = []
        params = {}

        # Build conditions
        filters.each do |key, value|
          next if value.blank?
          key = key.to_sym
          case key
          when :search
            conditions << "(title #{like} :search OR description #{like} :search)"
            params[:search] = "%#{value}%"
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
