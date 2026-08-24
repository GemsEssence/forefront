module Forefront
  module Admins
    class RegistrationsController < Devise::RegistrationsController
      layout "forefront/application"

      before_action :configure_permitted_parameters
      before_action :block_signup, only: [:new, :create]

      protected

      def configure_permitted_parameters
        devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
        devise_parameter_sanitizer.permit(:account_update, keys: [:name])
      end

      private

      def block_signup
        redirect_to new_admin_session_path, alert: "Sign-up is invite-only. Contact your administrator for access."
      end
    end
  end
end