module Forefront
  module LeadServices
    class Filter
      attr_reader :scope, :filters

      def initialize(scope: Lead.all, filters: {})
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
          when :active
            next if value != 'true'
            conditions << "status NOT IN ('Won', 'Lost')"
          when :won
            next if value != 'true'
            conditions << "status = 'Won'"
          when :lost
            next if value != 'true'
            conditions << "status = 'Lost'"
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