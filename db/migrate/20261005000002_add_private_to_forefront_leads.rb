# A Lead created by hand in the Lead form is private (CONTEXT.md: Private
# Lead): hidden from the owner's Manager until it is Won, Lost or shared.
class AddPrivateToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_leads, :private, :boolean, null: false, default: false
  end
end
