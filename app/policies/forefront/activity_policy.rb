module Forefront
  class ActivityPolicy
    attr_reader :current_admin, :activity

    def initialize(current_admin, activity)
      @current_admin = current_admin
      @activity = activity
    end

    def create?
      return true unless activity.actable.present?
      
      actable = activity.actable
      creator? || 
      (actable.respond_to?(:created_by_id) && actable.created_by_id == current_admin.id) ||
      (actable.respond_to?(:assigned_to_id) && actable.assigned_to_id == current_admin.id)
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

    def creator?
      activity.created_by_id == current_admin.id
    end
  end
end
