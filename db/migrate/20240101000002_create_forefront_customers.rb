class CreateForefrontCustomers < ActiveRecord::Migration[7.0]
  def change
    create_table :forefront_customers do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :address
      t.string :business_name

      t.timestamps
    end

    add_index :forefront_customers, :email, unique: true
    add_index :forefront_customers, :phone
  end
end

