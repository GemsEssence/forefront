# A Customer now needs an email *or* a phone number, not necessarily both.
class AllowForefrontCustomersWithoutEmail < ActiveRecord::Migration[6.1]
  def change
    change_column_null :forefront_customers, :email, true
  end
end
