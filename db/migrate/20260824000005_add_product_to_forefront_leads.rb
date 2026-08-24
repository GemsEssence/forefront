class AddProductToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_reference :forefront_leads, :product, null: true, foreign_key: { to_table: :forefront_products }
  end
end
