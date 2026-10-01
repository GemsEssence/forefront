# The Campaign an enquiry Ticket is credited to (ADR 0005).
class AddCampaignToForefrontTickets < ActiveRecord::Migration[6.1]
  def change
    add_reference :forefront_tickets, :campaign, foreign_key: { to_table: :forefront_campaigns }
  end
end
