class CreateForefrontSubscriptions < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_subscriptions do |t|
      t.references :customer, null: false, foreign_key: { to_table: :forefront_customers }
      t.references :product, null: false, foreign_key: { to_table: :forefront_products }
      t.references :lead, null: false, foreign_key: { to_table: :forefront_leads }, index: { unique: true }
      t.date :expires_at, null: false

      t.timestamps
    end
  end
end
