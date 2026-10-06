module Forefront
  class ActivityPolicy
    attr_reader :current_admin, :activity

    def initialize(current_admin, activity)
      @current_admin = current_admin
      @activity = activity
    end

    # A note needs the right to work on the Lead or Ticket it is added to,
    # the same as a Followup.
    def create?
      actable = activity.actable
      return true unless actable.present?

      work_policy_for(actable).note?
    end

    def update?
      creator?
    end

    def edit?
      update?
    end

    def destroy?
      creator?
    end

    private

    def work_policy_for(actable)
      policy_class = actable.is_a?(Forefront::Lead) ? LeadPolicy : TicketPolicy
      policy_class.new(current_admin, actable)
    end

    def creator?
      activity.created_by_id == current_admin.id
    end
  end
end
