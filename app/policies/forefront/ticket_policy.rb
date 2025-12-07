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
      ticket.created_by_id == current_admin.id
    end

    def assignee?
      ticket.assigned_to_id == current_admin.id
    end
  end
end
