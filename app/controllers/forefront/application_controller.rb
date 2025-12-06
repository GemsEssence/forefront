module Forefront
  class ApplicationController < ActionController::Base
    before_action :authenticate_admin!

    helper_method :current_admin, :admin_signed_in?
  end
end
