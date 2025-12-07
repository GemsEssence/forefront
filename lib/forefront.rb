require "forefront/version"
require "forefront/engine"
require "forefront/pundit"

module Forefront
  mattr_accessor :admin_class, :authenticate_with, :current_admin_method, default: nil

  def self.setup
    yield self
  end

  # Defaults for Devise Admin authentication
  # Can be overridden in host app initializer if needed
  self.admin_class          = "Forefront::Admin"
  self.authenticate_with    = :authenticate_admin!
  self.current_admin_method = :current_admin
end
