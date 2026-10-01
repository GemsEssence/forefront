# A Lead has many Tickets: the one it was converted from and those for the
# sales work done under it (a demo, a Proposal). Renewal Tickets never belong
# to a Lead (ADR 0003).
class AddLeadToForefrontTickets < ActiveRecord::Migration[6.1]
  def change
    add_reference :forefront_tickets, :lead, foreign_key: { to_table: :forefront_leads }
  end
end
