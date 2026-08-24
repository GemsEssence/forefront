module Forefront
  class TargetPolicy < ApplicationPolicy
    def index?
      true
    end

    def new?
      manages_targets?
    end

    def create?
      return false unless manages_targets?
      return true if pundit_user.admin?

      pundit_user.direct_report_ids.include?(record.admin_id)
    end

    def edit?
      create?
    end

    def update?
      create?
    end

    class Scope < Scope
      def resolve
        if pundit_user.admin?
          scope.all
        elsif pundit_user.manager?
          scope.where(admin_id: pundit_user.direct_report_ids)
        else
          scope.where(admin_id: pundit_user.id)
        end
      end
    end

    private

    def manages_targets?
      pundit_user.admin? || pundit_user.manager?
    end
  end
end
