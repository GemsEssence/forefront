class CreateForefrontLeadShares < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_lead_shares do |t|
      t.references :lead, null: false, foreign_key: { to_table: :forefront_leads }, index: { unique: true }
      t.references :recorded_by, null: false, foreign_key: { to_table: :forefront_admins }

      t.timestamps
    end
  end
end
