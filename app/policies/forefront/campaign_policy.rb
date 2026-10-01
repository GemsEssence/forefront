module Forefront
  # Any Staff member runs Campaigns; whoever created one, and Managers and
  # Admins, can change it.
  class CampaignPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def create?
      true
    end

    def new?
      create?
    end

    def update?
      pundit_user.admin? || pundit_user.manager? || record.created_by_id == pundit_user.id
    end

    def edit?
      update?
    end

    class Scope < Scope
      def resolve
        scope.all
      end
    end
  end
end
