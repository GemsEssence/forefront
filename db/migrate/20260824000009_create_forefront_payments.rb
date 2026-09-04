class CreateForefrontPayments < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_payments do |t|
      t.references :lead, null: false, foreign_key: { to_table: :forefront_leads }, index: { unique: true }
      t.decimal :total_amount, precision: 12, scale: 2, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :paid_at

      t.timestamps
    end
  end
end
