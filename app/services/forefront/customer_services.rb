module Forefront
  module CustomerServices
    class Filter
      attr_reader :scope, :filters

      def initialize(scope: Customer.all, filters: {})
        @scope = scope
        @filters = filters
      end

      def call
        like = Forefront::ApplicationRecord.case_insensitive_like
        conditions = []
        params = {}

        # Build conditions - search takes precedence
        if filters[:search].present?
          conditions << "(name #{like} :search OR email #{like} :search OR phone #{like} :search OR business_name #{like} :search)"
          params[:search] = "%#{filters[:search]}%"
        else
          # Individual field filters (only if no general search)
          if filters[:name].present?
            conditions << "name #{like} :name"
            params[:name] = "%#{filters[:name]}%"
          end

          if filters[:email].present?
            conditions << "email #{like} :email"
            params[:email] = "%#{filters[:email]}%"
          end

          if filters[:phone].present?
            conditions << "phone #{like} :phone"
            params[:phone] = "%#{Customer.national_number(filters[:phone], country_code: Forefront.default_country_code)}%"
          end

          if filters[:business_name].present?
            conditions << "business_name #{like} :business_name"
            params[:business_name] = "%#{filters[:business_name]}%"
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
        when 'name'
          result = result.order(:name)
        when 'email'
          result = result.order(:email)
        when 'created_at'
          result = result.order(created_at: :desc)
        else
          result = result.order(created_at: :desc)
        end

        result
      end
    end
  end
end