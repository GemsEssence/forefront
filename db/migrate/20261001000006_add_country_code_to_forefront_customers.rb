# Customers are matched by country code and phone together (the Signup API
# sends both), so a phone becomes digits only, without a trunk zero or its
# country code, with the country code alongside. Existing numbers get the
# host's default country code, losing a leading copy of it ("+91 98765...")
# or a trunk zero ("098765..."). A number in some other "+<code>" keeps its
# digits under the default code, for someone to correct.
class AddCountryCodeToForefrontCustomers < ActiveRecord::Migration[6.1]
  class Customer < ActiveRecord::Base
    self.table_name = "forefront_customers"
  end

  def up
    add_column :forefront_customers, :country_code, :string

    default_code = Forefront.default_country_code
    Customer.where.not(phone: nil).find_each do |customer|
      digits = customer.phone.delete("^0-9")
      digits = digits.delete_prefix(default_code.delete("+")) if customer.phone.strip.start_with?(default_code)
      customer.update_columns(country_code: default_code, phone: digits.sub(/\A0+/, ""))
    end

    add_index :forefront_customers, [ :country_code, :phone ], unique: true
  end

  def down
    remove_index :forefront_customers, [ :country_code, :phone ]
    remove_column :forefront_customers, :country_code
  end
end
