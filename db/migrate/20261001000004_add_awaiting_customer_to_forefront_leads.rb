# When the Customer went quiet on a Lead (after a demo, a Proposal...): set
# while Staff wait on them, with a Followup scheduled, and cleared when they
# respond or the stage moves on.
class AddAwaitingCustomerToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_leads, :awaiting_customer_since, :datetime
  end
end
