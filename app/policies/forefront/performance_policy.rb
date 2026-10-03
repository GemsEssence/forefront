module Forefront
  # /performance: everyone may open it. What each role sees is decided by
  # Dashboard::Scope (a Sales person only themselves). The trend of one
  # person is limited to the people the viewer may see.
  class PerformancePolicy
    def initialize(current_admin, record = nil)
      @current_admin = current_admin
      @record = record
    end

    def index?
      true
    end

    private

    attr_reader :current_admin, :record
  end
end
