module Forefront
  class DashboardController < ApplicationController
    skip_after_action :verify_policy_scoped

    def index
      authorize :dashboard, :index?, policy_class: Forefront::DashboardPolicy
      @from = parse_date(params[:from])
      @to = parse_date(params[:to])
      @summary = DashboardSummary.new(current_admin, from: @from, to: @to)
    end

    private

    def parse_date(value)
      Date.parse(value) if value.present?
    rescue ArgumentError
      nil
    end
  end
end
