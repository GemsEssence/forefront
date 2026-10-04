module Forefront
  # Reports: everyone sees the list; each report names the roles that may open it.
  class ReportPolicy
    def initialize(current_admin, record = nil)
      @current_admin = current_admin
      @record = record
    end

    def index?
      true
    end

    # record: a Reports::Base subclass
    def show?
      record.roles.include?(current_admin.role)
    end

    private

    attr_reader :current_admin, :record
  end
end
