module Forefront
  module Reports
    # Work that arrived with nobody assigned: how much entered the pool in the
    # period, how much is still waiting, and who claimed how quickly.
    class Pool < Base
      report key: "pool", title: "Pool", group: :activity, roles: TEAM_ROLES, filters: %i[campaign]

      def columns
        [ column(:who, "Who", :text), column(:entered, "Entered pool", :count),
          column(:still, "Still unclaimed", :count), column(:claims, "Claims", :count), column(:hours, "Avg hours to claim", :hours) ]
      end

      def rows
        entered = entered_pool
        still = entered.count { |record| record.assigned_to_id.nil? }
        [ [ "All", entered.size, still, nil, nil ] ] + context.scope.rows.filter_map do |person|
          claims = claims_for(person)
          next if claims.empty?

          [ person.name, nil, nil, claims.size, mean(claims.map { |claim| (claim.created_at - claim.assignable.created_at) / 1.hour }) ]
        end
      end

      private

      # Claims in the period whose record still exists and, with a Campaign
      # filter, belongs to that Campaign.
      def claims_for(person)
        claims = Dashboard::Metrics.claims(context.scope.for_member(person)).includes(:assignable).to_a.reject { |claim| claim.assignable.nil? }
        context.campaign_id ? claims.select { |claim| claim.assignable.campaign_id == context.campaign_id } : claims
      end

      # Created in the period with no assignee on the created event (a record
      # created assigned has "assigned_to" => [nil, name]; unassigned has no key).
      def entered_pool
        events = AuditEvent.where(action: "created", auditable_type: [ Ticket.name, Lead.name ], created_at: context.period.times)
        unassigned = events.select { |event| event.audited_changes.fetch("assigned_to", [ nil, nil ]).last.blank? }
        ids = unassigned.group_by(&:auditable_type).transform_values { |list| list.map(&:auditable_id) }
        tickets = context.campaign_id ? Ticket.where(campaign_id: context.campaign_id) : Ticket.all
        leads = context.campaign_id ? Lead.where(campaign_id: context.campaign_id) : Lead.all
        scoped(tickets.where(id: ids.fetch(Ticket.name, []))) + scoped(leads.where(id: ids.fetch(Lead.name, [])))
      end

      def scoped(relation)
        context.scope.product_id ? relation.where(product_id: context.scope.product_id).to_a : relation.to_a
      end
    end
  end
end
