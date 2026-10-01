module Forefront
  module Admins
    class PasswordsController < Devise::PasswordsController
      layout "forefront/application"
      helper Forefront::SidebarHelper
    end
  end
end