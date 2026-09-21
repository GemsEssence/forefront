class AddExternalReferenceToForefrontCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_customers, :external_id, :string
    add_column :forefront_customers, :external_type, :string

    add_index :forefront_customers, [ :external_type, :external_id ], unique: true, name: "index_forefront_customers_on_external_reference"
  end
end
