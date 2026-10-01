module Forefront
  class LeadPolicy
    include UnassignedPool

    attr_reader :current_admin, :lead

    def initialize(current_admin, lead)
      @current_admin = current_admin
      @lead = lead
    end

    def index?
      true
    end

    def show?
      super_admin? || owner? || assignee? || manages_owner_or_assignee? || pooled_for_me?
    end

    def create?
      true
    end

    def new?
      create?
    end

    def update?
      super_admin? || owner? || assignee? || manages_owner_or_assignee?
    end

    def edit?
      update?
    end

    def destroy?
      super_admin?
    end

    # Moving a Lead out of Won or Lost undoes a recorded outcome, so it takes
    # an Admin, or a Manager responsible for the Lead.
    def reopen?
      super_admin? || (current_admin.manager? && (owner? || assignee? || manages_owner_or_assignee?))
    end

    def change_assignee?
      super_admin? || assignee? || manages_owner_or_assignee? || manages_pool?
    end

    class Scope
      def initialize(current_admin, scope)
        @current_admin = current_admin
        @scope = scope
      end

      def resolve
        if super_admin?
          @scope
        elsif @current_admin.manager?
          ids = @current_admin.direct_report_ids << @current_admin.id
          @scope.where("created_by_id IN (:ids) OR assigned_to_id IN (:ids)", ids: ids)
                .or(UnassignedPool.visible_to(@current_admin, @scope))
        else
          @scope.where(
            "created_by_id = ? OR assigned_to_id = ?",
            @current_admin.id,
            @current_admin.id
          ).or(UnassignedPool.visible_to(@current_admin, @scope))
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

    def record_in_pool
      lead
    end

    def owner?
      lead.created_by_id == current_admin.id
    end

    def assignee?
      lead.assigned_to_id == current_admin.id
    end

    def manages_owner_or_assignee?
      current_admin.manager? && (
        current_admin.direct_report_ids.include?(lead.created_by_id) ||
        current_admin.direct_report_ids.include?(lead.assigned_to_id)
      )
    end
  end
end
