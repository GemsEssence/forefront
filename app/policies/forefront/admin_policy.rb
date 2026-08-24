module Forefront
  class AdminPolicy < ApplicationPolicy
    def index?
      manages_staff?
    end

    def new?
      manages_staff?
    end

    def create?
      return false unless manages_staff?
      return true if pundit_user.admin?

      record.sales_person? && record.manager_id == pundit_user.id
    end

    def edit?
      return false unless manages_staff?
      return true if pundit_user.admin?

      record.manager_id == pundit_user.id
    end

    def update?
      edit?
    end

    class Scope < Scope
      def resolve
        if pundit_user.admin?
          scope.all
        elsif pundit_user.manager?
          scope.where(manager_id: pundit_user.id)
        else
          scope.none
        end
      end
    end

    private

    def manages_staff?
      pundit_user.admin? || pundit_user.manager?
    end
  end
end
