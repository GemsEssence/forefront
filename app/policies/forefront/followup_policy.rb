module Forefront
  class FollowupPolicy < ApplicationPolicy
    def create?
      # creation is allowed for any signed-in admin; controller ensures followupable update permission
      pundit_user.present?
    end

    def update?
      # assignee or creator or super-admin can update
      return true if pundit_user&.super_admin?
      return true if record.assigned_to_id == pundit_user&.id
      return true if record.created_by_id == pundit_user&.id
      false
    end

    class Scope < Scope
      def resolve
        # super-admin sees everything
        return scope.all if pundit_user&.super_admin?
        # otherwise, followups where assigned_to or created_by is the current admin
        scope.where('assigned_to_id = :id OR created_by_id = :id', id: pundit_user&.id)
      end
    end
  end
end
