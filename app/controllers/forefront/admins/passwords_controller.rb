module Forefront
  class PasswordsController < Devise::PasswordsController
    layout "forefront/application"
  end
end