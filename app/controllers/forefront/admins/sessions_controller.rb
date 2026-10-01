module Forefront
  module Admins
    class SessionsController < Devise::SessionsController
      layout "forefront/application"
      helper Forefront::SidebarHelper
    end
  end
end