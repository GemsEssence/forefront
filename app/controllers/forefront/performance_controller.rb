module Forefront
  # How each person (or team) is performing: a ranking for Managers and
  # Admins, and a Sales person's own numbers.
  class PerformanceController < ApplicationController
    skip_after_action :verify_policy_scoped

    def index
      authorize :performance, :index?, policy_class: Forefront::PerformancePolicy
      @scope = Dashboard::Scope.from_params(current_admin, params)
      @performance = Performance.new(@scope)
      sort = params[:sort]
      @sort = @performance.columns.any? { |column| column.key.to_s == sort } ? sort : Performance::DEFAULT_SORT
      @dir = params[:dir] == "asc" ? "asc" : "desc"
      @rows = @performance.sorted_rows(@sort, @dir)
    end

    def trend
      @person = Admin.people.find(params[:id])
      raise ActiveRecord::RecordNotFound unless Forefront::PerformancePolicy.new(current_admin, @person).trend?

      authorize @person, :trend?, policy_class: Forefront::PerformancePolicy
      @scope = Dashboard::Scope.from_params(current_admin, params.permit(:product_id))
      @performance = Performance.new(@scope)
      @rows = @performance.trend(@person)
    end
  end
end
