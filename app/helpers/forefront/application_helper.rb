module Forefront
  module ApplicationHelper
    # Devise provides current_admin and admin_signed_in? automatically
    # These methods are available through Devise helpers

    def can_create_activity?(actable)
      admin_signed_in? && policy(Forefront::Activity.new(actable: actable, created_by: current_admin)).create?
    end
  end
end
