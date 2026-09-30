module Forefront
  class AuditEventPolicy < ApplicationPolicy
    def index?
      pundit_user.admin? || pundit_user.manager?
    end

    class Scope < Scope
      def resolve
        if pundit_user.admin?
          scope.all
        elsif pundit_user.manager?
          scope.where(actor_id: pundit_user.direct_report_ids << pundit_user.id)
        else
          scope.none
        end
      end
    end
  end
end
