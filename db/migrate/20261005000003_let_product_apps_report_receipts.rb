# A Product's own application reports money a Customer paid in it
# (CONTEXT.md: Unattached Receipt, ADR 0008). Such a Receipt arrives before
# anyone has said which Payment it belongs to, so payment_id becomes
# optional and the Receipt carries the Product, the app's own reference and
# the phone number it came with, plus the Customer when the phone matched.
class LetProductAppsReportReceipts < ActiveRecord::Migration[6.1]
  def change
    change_column_null :forefront_receipts, :payment_id, true
    add_reference :forefront_receipts, :product, foreign_key: { to_table: :forefront_products }
    add_reference :forefront_receipts, :customer, foreign_key: { to_table: :forefront_customers }
    add_column :forefront_receipts, :external_reference, :string
    add_column :forefront_receipts, :country_code, :string
    add_column :forefront_receipts, :phone, :string
    add_column :forefront_receipts, :discarded_at, :datetime
    add_column :forefront_receipts, :discard_note, :text
    add_reference :forefront_receipts, :discarded_by, foreign_key: { to_table: :forefront_admins }
    add_index :forefront_receipts, [ :product_id, :external_reference ], unique: true
  end
end
