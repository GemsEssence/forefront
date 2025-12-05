module Forefront
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      source_root File.expand_path("templates", __dir__)

      def create_initializer
        template "forefront_initializer.rb", "config/initializers/forefront.rb"
      end

      def mount_engine
        route 'mount Forefront::Engine, at: "/forefront"'
      end

      def create_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_reviews'
      end

      def run_migrations
        run_migrations = options[:auto_run_migrations] || ['', 'y', 'Y'].include?(ask 'Would you like to run the migrations now? [Y/n]')
        if run_migrations
          run 'bundle exec rake db:migrate'
        else
          puts 'Skipping rake db:migrate, don\'t forget to run it!'
        end
      end
    end
  end
end
