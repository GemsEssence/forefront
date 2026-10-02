module Forefront
  # The records behind a dashboard number, built from the same metric and filters.
  class DashboardMetricsController < ApplicationController
    def show
      @metric = Dashboard::Metrics.find(params[:key]) or raise ActiveRecord::RecordNotFound
      authorize @metric, :metric?, policy_class: Forefront::DashboardPolicy
      @scope = Dashboard::Scope.from_params(current_admin, params, own: params[:tab] == "my_day")
      relation = @metric.relation(@scope, params[:slice].presence)
      @records = relation.reorder(relation.klass.arel_table[:id].desc).page(params[:page])
    end
  end
end
