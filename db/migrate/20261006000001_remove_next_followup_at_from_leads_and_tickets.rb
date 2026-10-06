# Followup records are the only follow-up (CONTEXT.md: Followup). The
# free-typed "Next Follow-up" date on Leads and Tickets was a second,
# disconnected notion that nothing but a display flag read.
class RemoveNextFollowupAtFromLeadsAndTickets < ActiveRecord::Migration[6.1]
  def change
    remove_column :forefront_leads, :next_followup_at, :datetime
    remove_column :forefront_tickets, :next_followup_at, :datetime
  end
end
