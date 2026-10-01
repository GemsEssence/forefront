# A Lead converted from a Campaign's enquiry keeps the Campaign's credit
# (ADR 0005), so a Campaign's sales can be counted.
class AddCampaignToForefrontLeads < ActiveRecord::Migration[6.1]
  def change
    add_reference :forefront_leads, :campaign, foreign_key: { to_table: :forefront_campaigns }
  end
end
