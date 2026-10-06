# Where a Product's own application lists its active subscriptions and
# their end dates, for the daily Expiry pull (CONTEXT.md, ADR 0007). The
# token is stored as entered so Forefront can send it; a host may add Active
# Record encryption for the column later.
class AddExpiryEndpointToForefrontProducts < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_products, :expiry_endpoint_url, :string
    add_column :forefront_products, :expiry_endpoint_token, :string
  end
end
