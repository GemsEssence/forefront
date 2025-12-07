module Forefront
  module PunditHelper
    def pundit_user
      current_admin
    end

    def authorize_or_redirect(*args)
      authorize(*args)
    rescue Pundit::NotAuthorizedError
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || root_path)
    end
  end
end
