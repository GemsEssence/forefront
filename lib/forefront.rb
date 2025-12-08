require "rails"
require "forefront/version"
require "forefront/engine"
require "forefront/pundit"

module Forefront
  # Configuration accessors for pluggable authentication
  mattr_accessor :admin_class, :authenticate_with, :current_admin_method, default: nil

  def self.setup
    yield self
  end

  # ========== CONFIGURATION GUIDE ==========
  # The Forefront gem supports two authentication modes:
  #
  # 1. DEFAULT (Forefront::Admin with Devise):
  #    No configuration needed. Gem uses built-in Admin model.
  #
  # 2. CUSTOM HOST APP AUTHENTICATION:
  #    In your host app's config/initializers/forefront.rb:
  #
  #    Forefront.setup do |config|
  #      # User model class name (as string)
  #      config.admin_class = "User"
  #      
  #      # Authentication method to call in controller
  #      config.authenticate_with = :authenticate_user!
  #      
  #      # Current user method to get authenticated user
  #      config.current_admin_method = :current_user
  #    end
  #
  # REQUIRED: Host app must define a method to check super_admin status:
  #   def super_admin?
  #     role == 'super_admin'  # or your custom logic
  #   end
  # =========================================

  # Defaults for Devise Admin authentication
  # Can be overridden in host app initializer if needed
  self.admin_class          = "Forefront::Admin"
  self.authenticate_with    = :authenticate_admin!
  self.current_admin_method = :current_admin

  # Helper method to get the configured admin class
  def self.admin_class_name
    @admin_class_name ||= admin_class.constantize
  end
end
