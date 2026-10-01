module Forefront
  # My work is for Staff who do the work: Sales persons and Managers. Admins
  # oversee it through the dashboard, reports and the audit log instead.
  class MyWorkPolicy
    def initialize(current_admin, record = nil)
      @current_admin = current_admin
      @record = record
    end

    def index?
      !current_admin.admin?
    end

    private

    attr_reader :current_admin, :record
  end
end
