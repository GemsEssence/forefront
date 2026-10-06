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
      super_admin? || owner? || assignee? || manages_owner_or_assignee? || pooled_for_me? || participant?
    end

    def create?
      true
    end

    def new?
      create?
    end

    # The edit form: the assignee, their Manager, or an Admin.
    def update?
      (super_admin? || assignee? || manages_owner_or_assignee?) && !locked?
    end

    # The day-to-day work (CONTEXT.md: only the assignee works a Lead).
    def work?
      assignee? && !locked?
    end

    # Notes: the assignee, share participants, and the Manager overseeing.
    def note?
      work? || (participant? && !locked?) || manages_owner_or_assignee?
    end

    # Moving the stage: the assignee through the stage actions, or a Manager
    # correcting it. Never an Admin.
    def move_stage?
      work? || manages_owner_or_assignee?
    end

    # Payments, Installments and Receipts: the assignee only.
    def record_money?
      work?
    end

    def attach_receipt?
      work? || manages_owner_or_assignee?
    end

    def share?
      work? || manages_owner_or_assignee?
    end

    # A passed Deadline (CONTEXT.md) stops the assignee; a Manager or Admin
    # extends it, within the limit, with a note.
    def extend_deadline?
      super_admin? || manages_owner_or_assignee?
    end

    def edit?
      update?
    end

    # Followups: the assignee and the people the Lead is shared with.
    def work_on?
      work? || (participant? && !locked?)
    end

    def destroy?
      super_admin?
    end

    # Moving a Lead out of Won or Lost undoes a recorded outcome, so it takes
    # an Admin, or a Manager responsible for the Lead.
    def reopen?
      super_admin? || (current_admin.manager? && (owner? || assignee? || manages_owner_or_assignee?))
    end

    # A Private Lead changes hands only through sharing, or an Admin.
    def change_assignee?
      super_admin? || (!lead.private? && (assignee? || manages_owner_or_assignee? || manages_pool?))
    end

    # Someone the Lead is shared with (a LeadShare participant).
    def participant?
      return false unless lead.persisted?

      Forefront::LeadShareParticipant.joins(:lead_share)
                                     .exists?(admin_id: current_admin.id, forefront_lead_shares: { lead_id: lead.id })
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
                .merge(Lead.visible_to(@current_admin))
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

    # Once the deadline has passed, only a Manager or Admin may act.
    def locked?
      lead.deadline_passed? && !extend_deadline?
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

    # A Manager's reach stops at a report's Private Lead (CONTEXT.md).
    def manages_owner_or_assignee?
      current_admin.manager? && !lead.private? && (
        current_admin.direct_report_ids.include?(lead.created_by_id) ||
        current_admin.direct_report_ids.include?(lead.assigned_to_id)
      )
    end
  end
end
