module Forefront
  module ApplicationHelper
    # Devise provides current_admin and admin_signed_in? automatically
    # These methods are available through Devise helpers

    def can_create_activity?(actable)
      return false unless admin_signed_in?
      actable.created_by_id == current_admin.id || 
      (actable.respond_to?(:assigned_to_id) && actable.assigned_to_id == current_admin.id)
    end
  end
end
