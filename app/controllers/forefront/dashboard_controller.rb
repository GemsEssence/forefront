module Forefront
  class DashboardController < ApplicationController
    skip_after_action :verify_policy_scoped

    def index
      authorize :dashboard, :index?, policy_class: Forefront::DashboardPolicy
      @summary = DashboardSummary.new(current_admin)
    end
  end
end

