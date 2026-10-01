module Forefront
  # A Staff member deliberately revealing a Customer's contact details
  # (CONTEXT.md). Shown for a minute; an Action against the Customer is
  # expected afterwards.
  class ContactReveal < ApplicationRecord
    SHOWN_FOR = 1.minute

    # The audit-log actions that count as an Action (CONTEXT.md): creating a
    # Ticket or Lead, an Activity, a Followup, or a stage/status change.
    ACTIONS = %w[
      created added_activity scheduled_followup updated_followup changed_status
      marked_awaiting_customer customer_responded converted
    ].freeze

    belongs_to :admin, class_name: "Forefront::Admin"
    belongs_to :customer, class_name: "Forefront::Customer"

    # Answered once whoever revealed has recorded an Action on one of the
    # Customer's Tickets or Leads since.
    def answered?
      since = AuditEvent.where(actor_id: admin_id, action: ACTIONS).where(created_at: created_at..)
      since.where(auditable_type: Ticket.name, auditable_id: customer.tickets.select(:id))
           .or(since.where(auditable_type: Lead.name, auditable_id: customer.leads.select(:id)))
           .exists?
    end
  end
end
