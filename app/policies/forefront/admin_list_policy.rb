module Forefront
  # Only Admins maintain the lists that replace hard-coded enums (see AdminList).
  class AdminListPolicy < ApplicationPolicy
    def index?
      pundit_user.admin?
    end

    def create?
      pundit_user.admin?
    end

    def edit?
      pundit_user.admin?
    end

    def update?
      pundit_user.admin?
    end

    def destroy?
      pundit_user.admin?
    end

    class Scope < Scope
      def resolve
        scope.all
      end
    end
  end
end
