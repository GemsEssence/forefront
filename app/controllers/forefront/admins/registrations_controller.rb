module Forefront
  module Admins
    class RegistrationsController < Devise::RegistrationsController
      layout "forefront/application"
    end
  end
end