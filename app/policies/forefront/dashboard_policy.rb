module Forefront
  class DashboardPolicy
    def initialize(current_admin, record = nil)
      @current_admin = current_admin
      @record = record
    end

    def index?
      # # any signed-in admin can access the dashboard
      # current_admin.present?
      true
    end

    private

    attr_reader :current_admin, :record
  end
end
