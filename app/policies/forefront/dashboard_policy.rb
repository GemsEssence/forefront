module Forefront
  class DashboardPolicy
    def initialize(current_admin, record = nil)
      @current_admin = current_admin
      @record = record
    end

    def index?
      true
    end

    # record: a Dashboard::Metrics::Metric
    def metric?
      record.open_to?(current_admin)
    end

    private

    attr_reader :current_admin, :record
  end
end
