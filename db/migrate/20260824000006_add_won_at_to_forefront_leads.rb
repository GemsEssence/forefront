class AddWonAtToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_leads, :won_at, :datetime
  end
end
