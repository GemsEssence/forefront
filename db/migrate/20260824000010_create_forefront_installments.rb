class CreateForefrontInstallments < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_installments do |t|
      t.references :payment, null: false, foreign_key: { to_table: :forefront_payments }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :due_on, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :paid_at

      t.timestamps
    end
  end
end
