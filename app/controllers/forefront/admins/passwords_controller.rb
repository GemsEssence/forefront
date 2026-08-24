module Forefront
  module Admins
    class PasswordsController < Devise::PasswordsController
      layout "forefront/application"
    end
  end
end