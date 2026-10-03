module Forefront
  # How each person (or team) is performing: a ranking for Managers and
  # Admins, and a Sales person's own numbers.
  class PerformanceController < ApplicationController
    skip_after_action :verify_policy_scoped

    def index
      authorize :performance, :index?, policy_class: Forefront::PerformancePolicy
      @scope = Dashboard::Scope.from_params(current_admin, params)
      @performance = Performance.new(@scope)
      @rows = @performance.rows
    end
  end
end
