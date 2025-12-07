require "turbo-rails"

module Forefront
  class Engine < ::Rails::Engine
    isolate_namespace Forefront

    initializer "forefront.assets.precompile" do |app|
      app.config.assets.precompile += %w[forefront_manifest.js forefront.css]
    end

    config.to_prepare do
      if defined?(Devise)
        Devise::SessionsController.layout "forefront/application"
        Devise::RegistrationsController.layout "forefront/application"
        Devise::PasswordsController.layout "forefront/application"
      end
    end
  end
end
