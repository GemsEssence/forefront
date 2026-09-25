# Deal value now comes from each won Lead's Payment, not a fixed Product price.
class RemovePriceFromForefrontProducts < ActiveRecord::Migration[6.1]
  def change
    remove_column :forefront_products, :price, :decimal, precision: 10, scale: 2, default: "0.0", null: false
  end
end
