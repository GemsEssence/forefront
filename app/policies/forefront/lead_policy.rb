module Forefront
  class LeadPolicy
    attr_reader :current_admin, :lead

    def initialize(current_admin, lead)
      @current_admin = current_admin
      @lead = lead
    end

    def index?
      true
    end

    def show?
      super_admin? || owner? || assignee?
    end

    def create?
      true
    end

    def new?
      create?
    end

    def update?
      owner? || assignee?
    end

    def edit?
      update?
    end

    def destroy?
      super_admin?
    end

    class Scope
      def initialize(current_admin, scope)
        @current_admin = current_admin
        @scope = scope
      end

      def resolve
        if super_admin?
          @scope
        else
          @scope.where(
            "created_by_id = ? OR assigned_to_id = ?",
            @current_admin.id,
            @current_admin.id
          )
        end
      end

      private

      def super_admin?
        @current_admin.super_admin?
      end
    end

    private

    def super_admin?
      current_admin.super_admin?
    end

    def owner?
      lead.created_by_id == current_admin.id
    end

    def assignee?
      lead.assigned_to_id == current_admin.id
    end
  end
end
