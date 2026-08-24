class CreateForefrontTargets < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_targets do |t|
      t.references :admin, null: false, foreign_key: { to_table: :forefront_admins }
      t.references :product, null: false, foreign_key: { to_table: :forefront_products }
      t.string :metric, null: false
      t.decimal :goal_value, precision: 12, scale: 2, null: false
      t.string :period, null: false
      t.date :starts_on, null: false

      t.timestamps
    end

    add_index :forefront_targets, [ :admin_id, :product_id, :starts_on, :period ], unique: true, name: "index_forefront_targets_on_admin_product_period"
  end
end
