class CreateForefrontProducts < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_products do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end
