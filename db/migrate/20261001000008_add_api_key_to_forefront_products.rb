# Each Product's own application calls the Signup API with that Product's
# key. Only a digest is stored; the key itself is shown once, when made.
class AddApiKeyToForefrontProducts < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_products, :api_key_digest, :string
    add_column :forefront_products, :api_key_last4, :string
    add_column :forefront_products, :api_key_generated_at, :datetime
    add_index :forefront_products, :api_key_digest, unique: true
  end
end
