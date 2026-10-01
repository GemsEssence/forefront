# Each time a Staff member deliberately reveals a Customer's contact
# details. They're then expected to record an Action against that Customer.
class CreateForefrontContactReveals < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_contact_reveals do |t|
      t.references :admin, null: false, foreign_key: { to_table: :forefront_admins }
      t.references :customer, null: false, foreign_key: { to_table: :forefront_customers }
      t.timestamps
    end
  end
end
