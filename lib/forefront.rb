require "rails"
require "forefront/version"
require "forefront/engine"

module Forefront
  # Set to true in a host app initializer when Forefront runs as a plugin inside
  # that app, to let Customers be linked to the host app's own records.
  mattr_accessor :plugin_mode, default: false

  # ISO 4217 code for every amount Forefront shows, e.g. "USD". Set it in a
  # host app initializer; see Forefront::CurrencyHelper for how it's formatted.
  mattr_accessor :currency, default: "INR"

  # The country code a Customer's phone number gets when none is given, e.g.
  # "+44". Customers are matched by country code and phone together.
  mattr_accessor :default_country_code, default: "+91"

  # The From address of the alert emails Forefront sends. Mail goes out
  # through the host app's own Action Mailer settings.
  mattr_accessor :mailer_sender, default: "forefront@example.com"
end
