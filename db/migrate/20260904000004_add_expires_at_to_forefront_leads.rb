class AddExpiresAtToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_leads, :expires_at, :date
  end
end
