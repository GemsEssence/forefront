module Forefront
  # A Staff member deliberately revealing a Customer's contact details
  # (CONTEXT.md). Shown for a minute; an Action against the Customer is
  # expected afterwards.
  class ContactReveal < ApplicationRecord
    SHOWN_FOR = 1.minute


    belongs_to :admin, class_name: "Forefront::Admin"
    belongs_to :customer, class_name: "Forefront::Customer"

    # Answered once whoever revealed has recorded an Action on one of the
    # Customer's Tickets or Leads since.
    def answered?
      since = AuditEvent.actions.where(actor_id: admin_id).where(created_at: created_at..)
      since.where(auditable_type: Ticket.name, auditable_id: customer.tickets.select(:id))
           .or(since.where(auditable_type: Lead.name, auditable_id: customer.leads.select(:id)))
           .exists?
    end
  end
end
