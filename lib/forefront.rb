require "forefront/version"
require "forefront/engine"

module Forefront
  mattr_accessor :user_class, :authenticate_with, :current_user_method, default: nil

  def self.setup
    yield self
  end

  # Defaults, can be overridden in host app initializer
  self.user_class          = "User"
  self.authenticate_with   = :authenticate_user!
  self.current_user_method = :current_user
end
