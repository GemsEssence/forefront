# estimated_amount: the rough deal value entered when the Lead is created.
# actual_amount: what the deal really closed for, captured when it's marked
# won; amount-based Targets count this one.
class AddAmountsToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_leads, :estimated_amount, :decimal, precision: 12, scale: 2
    add_column :forefront_leads, :actual_amount, :decimal, precision: 12, scale: 2
  end
end
