module Forefront
  module Admins
    class SessionsController < Devise::SessionsController
      layout "forefront/application"
    end
  end
end