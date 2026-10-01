# A white-label sale asks the Customer to sign an agreement; when they did
# is recorded on the Lead as a milestone, never a stage or a gate on winning.
class AddWhiteLabelToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_leads, :white_label, :boolean, null: false, default: false
    add_column :forefront_leads, :agreement_signed_on, :date
  end
end
