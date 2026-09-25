require "rails"
require "forefront/version"
require "forefront/engine"

module Forefront
  # Set to true in a host app initializer when Forefront runs as a plugin inside
  # that app, to let Customers be linked to the host app's own records.
  mattr_accessor :plugin_mode, default: false
end
