module Forefront
  class Engine < ::Rails::Engine
    isolate_namespace Forefront

    initializer "forefront.assets.precompile" do |app|
      app.config.assets.precompile += %w[forefront_manifest.js forefront.css]
    end
  end
end
