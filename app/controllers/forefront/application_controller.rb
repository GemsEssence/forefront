module Forefront
  class ApplicationController < ActionController::Base
    include Pundit::Authorization

    before_action :authenticate_admin!
    after_action :verify_authorized, unless: -> { action_name == "index" }
    after_action :verify_policy_scoped, if: -> { action_name == "index" }

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    def pundit_user
      current_admin
    end

    private

    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || root_path)
    end
  end
end
