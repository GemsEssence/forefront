module Forefront
  class TicketPolicy
    attr_reader :current_admin, :ticket

    def initialize(current_admin, ticket)
      @current_admin = current_admin
      @ticket = ticket
    end

    def index?
      true
    end

    def show?
      super_admin? || owner? || assignee? || manages_owner_or_assignee?
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

    def change_assignee?
      super_admin? || assignee? || manages_owner_or_assignee?
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
      ticket.created_by_id == current_admin.id
    end

    def assignee?
      ticket.assigned_to_id == current_admin.id
    end

    def manages_owner_or_assignee?
      current_admin.manager? && (
        current_admin.direct_report_ids.include?(ticket.created_by_id) ||
        current_admin.direct_report_ids.include?(ticket.assigned_to_id)
      )
    end
  end
end
