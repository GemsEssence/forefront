# A Customer's origin is read off the work they came in through
# (CONTEXT.md: Source). Leads always had one; a Ticket created by hand had
# nowhere to record it, so a Customer with only such a Ticket had no origin.
class AddSourceToForefrontTickets < ActiveRecord::Migration[6.1]
  def change
    add_reference :forefront_tickets, :source, foreign_key: { to_table: :forefront_sources }
  end
end
