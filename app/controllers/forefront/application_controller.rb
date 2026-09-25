module Forefront
  class ApplicationController < ActionController::Base
    include Pundit::Authorization
    helper Forefront::ModalsHelper

    before_action :authenticate_admin!
    after_action :verify_authorized, unless: -> { action_name == "index" }
    after_action :verify_policy_scoped, if: -> { action_name == "index" }

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    def pundit_user
      current_admin
    end

    private

    # A modal form failed validation. For Turbo, re-render that modal open with
    # its errors (and whatever locals carry the submitted values) so it stays
    # on screen; without Turbo, fall back to redirecting back with the errors.
    def render_modal_errors(modal_id, partial:, locals:, errors:, fallback:)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(modal_id, partial: partial, locals: locals.merge(errors: errors, open: true)),
                 status: :unprocessable_entity
        end
        format.html { redirect_back fallback_location: fallback, alert: errors.join(", "), status: :see_other }
      end
    end

    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || root_path)
    end
  end
end
