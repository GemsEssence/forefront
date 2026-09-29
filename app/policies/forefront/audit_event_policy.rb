module Forefront
  class AuditEventPolicy < ApplicationPolicy
    def index?
      pundit_user.admin? || pundit_user.manager?
    end

    class Scope < Scope
      def resolve
        if pundit_user.admin?
          scope.all
        else
          scope.none
        end
      end
    end
  end
end
