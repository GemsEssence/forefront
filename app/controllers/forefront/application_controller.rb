module Forefront
  class ApplicationController < ActionController::Base
    include Pundit::Authorization

    # Dynamically set the authentication filter based on Forefront config
    before_action -> { send(Forefront.authenticate_with) }
    after_action :verify_authorized, except: :index
    after_action :verify_policy_scoped, only: :index

    helper_method :current_admin, :admin_signed_in?

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    def pundit_user
      current_admin
    end

    # Get the current authenticated user from the configured method
    def current_admin
      send(Forefront.current_admin_method)
    end

    # Check if a user is signed in using the configured method
    def admin_signed_in?
      current_admin.present?
    end

    private

    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || root_path)
    end
  end
end
