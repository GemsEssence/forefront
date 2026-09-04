class AddProductAndRenewalOutcomeToForefrontTickets < ActiveRecord::Migration[6.1]
  def change
    add_reference :forefront_tickets, :product, null: true, foreign_key: { to_table: :forefront_products }
    add_column :forefront_tickets, :renewal_outcome, :string
  end
end
