module Forefront
  # Each role's dashboard (docs/superpowers/specs/2026-10-02-role-dashboards-design.md):
  # My Day for a Sales person, Team (plus a My Day tab) for a Manager, Company for an Admin.
  class DashboardController < ApplicationController
    skip_after_action :verify_policy_scoped

    def index
      authorize :dashboard, :index?, policy_class: Forefront::DashboardPolicy
      own = current_admin.manager? && params[:tab] == "my_day"
      @scope = Dashboard::Scope.from_params(current_admin, params, own: own)
      @dashboard = if current_admin.admin? then "company"
      elsif current_admin.manager? && !own then "team"
      else "my_day"
      end
    end
  end
end
