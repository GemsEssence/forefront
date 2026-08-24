class CreateForefrontProductAllocations < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_product_allocations do |t|
      t.references :product, null: false, foreign_key: { to_table: :forefront_products }
      t.references :admin, null: false, foreign_key: { to_table: :forefront_admins }

      t.timestamps
    end

    add_index :forefront_product_allocations, [ :product_id, :admin_id ], unique: true
  end
end
