# Money actually received against a Payment, or one of its Installments.
# Several partial Receipts can together pay one Installment.
class CreateForefrontReceipts < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_receipts do |t|
      t.references :payment, null: false, foreign_key: { to_table: :forefront_payments }
      t.references :installment, foreign_key: { to_table: :forefront_installments }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :received_on, null: false
      t.string :payment_method, null: false
      t.string :reference
      t.references :recorded_by, null: false, foreign_key: { to_table: :forefront_admins }
      t.timestamps
    end
  end
end
