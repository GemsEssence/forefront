# app/queries/forefront/reports/conversion_funnel.rb
module Forefront
  module Reports
    # From enquiry to money: Enquiry/Signup Tickets created in the period, the
    # Leads converted from them, and how far those Leads got.
    class ConversionFunnel < Base
      report key: "conversion_funnel", title: "Conversion funnel", group: :pipeline, roles: TEAM_ROLES,
             filters: %i[source campaign]

      ORDER = %w[contacted demo proposal negotiation won].freeze

      def columns
        [ column(:step, "Step", :text), column(:count, "Reached", :count),
          column(:of_previous, "% of previous", :percent), column(:of_first, "% of first", :percent) ]
      end

      def rows
        tickets = context.tickets.where(category: %w[enquiry signup], created_at: context.period.times)
        converted = tickets.where(id: AuditEvent.where(action: "converted", auditable_type: Ticket.name).select(:auditable_id))
        leads = context.leads.where(id: converted.where.not(lead_id: nil).select(:lead_id))
        steps = [
          [ "Enquiry or signup tickets", tickets.count ],
          [ "Converted to leads", leads.count ],
          [ "Contacted", leads.count ], # converted Leads start at Contacted
          [ "Demo", reached(leads, "demo") ],
          [ "Proposal", reached(leads, "proposal") ],
          [ "Won", leads.won.count ],
          [ "Paid in full", leads.won.includes(payment: :installments).count { |lead| lead.payment&.fully_paid? } ]
        ]
        first = steps.first.last
        steps.each_with_index.map do |(label, count), index|
          previous = index.zero? ? nil : steps[index - 1].last
          [ label, count, percent(count, previous), index.zero? ? nil : percent(count, first) ]
        end
      end

      private

      # At the stage or past it now, or moved into it at some point.
      def reached(leads, stage)
        later = ORDER[ORDER.index(stage)..]
        leads.where(status: later)
             .or(leads.where(id: StatusHistory.where(trackable_type: Lead.name, new_status: Lead.statuses.fetch(stage)).select(:trackable_id)))
             .count
      end

      def percent(count, base)
        base.to_i.zero? ? nil : count * 100.0 / base
      end
    end
  end
end
