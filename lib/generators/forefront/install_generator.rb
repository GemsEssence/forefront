require "rails/generators"

module Forefront
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      source_root File.expand_path("templates", __dir__)

      def display_welcome
        puts "\n" + "="*70
        puts "Welcome to Forefront Engine Installation!"
        puts "="*70
      end

      def create_initializer
        template "forefront_initializer.rb", "config/initializers/forefront.rb"
        say "✓ Created config/initializers/forefront.rb"
        say "  (Optional: Customize authentication if using your own user model)"
      end

      def create_devise_initializer
        if defined?(Devise)
          unless File.exist?(Rails.root.join("config", "initializers", "devise.rb"))
            template "devise.rb", "config/initializers/devise.rb"
            say "✓ Created Devise initializer"
          else
            say "✓ Devise already configured"
          end
        else
          say_status :info, "Devise gem will be set up automatically", :blue
        end
      end

      def mount_engine
        route 'mount Forefront::Engine, at: "/forefront"'
        say "✓ Mounted Forefront at /forefront"
      end

      def create_migrations
        say "\nCopying migrations..."
        run 'bundle exec rake railties:install:migrations FROM=forefront'
        say "✓ Migrations ready"
      end

      def run_migrations
        puts "\n" + "="*70
        run_migrations = options[:auto_run_migrations] || ['', 'y', 'Y'].include?(ask 'Would you like to run migrations now? [Y/n]')
        if run_migrations
          say "Running migrations..."
          run 'bundle exec rake db:migrate'
          say "✓ Database initialized with Forefront tables"
        else
          say_status :alert, "Don't forget to run: rails db:migrate", :yellow
        end
      end

      def display_next_steps
        puts "\n" + "="*70
        puts "Forefront Installation Complete!"
        puts "="*70
        puts "\nYou're using Forefront's built-in authentication (Forefront::Admin)."
        puts "\nNext steps:\n\n"
        
        puts "1. If you haven't already, run migrations:"
        puts "   $ rails db:migrate\n\n"
        
        puts "2. Start your Rails server:"
        puts "   $ rails server\n\n"
        
        puts "3. Access Forefront:"
        puts "   http://localhost:3000/forefront\n\n"
        
        puts "4. Create your first admin via Rails console:"
        puts "   $ rails console"
        puts "   > Forefront::Admin.create!("
        puts "       name: 'Your Name',"
        puts "       email: 'you@example.com',"
        puts "       password: 'your_password',"
        puts "       super_admin: true"
        puts "     )\n\n"
        
        puts "Or sign up through the web interface at /forefront/admins/sign_up\n\n"
        
        puts "📚 For detailed information:"
        puts "   - GETTING_STARTED.md (how to use Forefront)"
        puts "   - AUTHENTICATION_CONFIGURATION.md (custom authentication)\n\n"
        
        puts "="*70 + "\n"
      end
    end
  end
end
