# app/queries/forefront/dashboard/metrics.rb
module Forefront
  module Dashboard
    # Every number on a dashboard is a Metric: a relation built from a Scope
    # (and optionally a slice, such as a stage). The dashboard shows its count
    # or a sum over it, and /dashboard/metrics/:key lists the same relation's
    # records, so a number and its list can't disagree.
    module Metrics
      ALL_ROLES = %w[sales_person manager admin].freeze
      TEAM_ROLES = %w[manager admin].freeze

      Metric = Struct.new(:key, :title, :kind, :roles, :periodic, :build, keyword_init: true) do
        def relation(scope, slice = nil)
          build.call(scope, slice)
        end

        def open_to?(admin)
          roles.include?(admin.role)
        end
      end

      @registry = {}

      def self.define(key, title:, kind:, roles: ALL_ROLES, periodic: false, &build)
        @registry[key.to_s] = Metric.new(key: key.to_s, title: title, kind: kind, roles: roles, periodic: periodic, build: build)
      end

      def self.fetch(key)
        @registry.fetch(key.to_s)
      end

      def self.find(key)
        @registry[key.to_s]
      end

      # Action strip
      define :overdue_followups, title: "Overdue Followups", kind: :followups do |scope, _|
        scope.followups.pending.where("scheduled_for < ?", Time.current)
      end

      define :followups_due_today, title: "Followups due today", kind: :followups do |scope, _|
        scope.followups.pending.where(scheduled_for: Time.current..Time.current.end_of_day)
      end

      define :newly_assigned, title: "Newly assigned", kind: :assignments, periodic: true do |scope, _|
        scope.assignments.where(created_at: scope.period.times)
      end

      ACTIVE_STAGES = %w[open contacted demo proposal negotiation].freeze

      # My pipeline / Leads by stage
      define :pipeline, title: "Open leads", kind: :leads do |scope, stage|
        leads = scope.leads.active
        next leads if stage.nil?

        ACTIVE_STAGES.include?(stage) ? leads.where(status: stage) : leads.none
      end

      define :pipeline_shared, title: "Open leads shared with others", kind: :leads do |scope, stage|
        fetch(:pipeline).relation(scope, stage).where(id: LeadShare.select(:lead_id))
      end

      # Orphan
      define :orphan_leads, title: "Open leads with no followup", kind: :leads do |scope, _|
        scope.leads.active.where.not(id: Followup.pending.where(followupable_type: Lead.name).select(:followupable_id))
      end

      # Target meter / Team target
      define :target_credit, title: "Leads counted towards the target", kind: :leads do |scope, target_id|
        target = scope.current_targets.find { |current| current.id == target_id.to_i }
        target ? target.credited_leads : Lead.none
      end

      # Shared with me
      define :shared_with_me, title: "Leads shared with me", kind: :leads, roles: %w[sales_person manager] do |scope, _|
        mine = LeadShareParticipant.joins(:lead_share).where(admin_id: scope.people_ids).select("forefront_lead_shares.lead_id")
        leads = Lead.where(id: mine).where.not(assigned_to_id: scope.people_ids)
        scope.product_id ? leads.where(product_id: scope.product_id) : leads
      end

      # Payments due / Payments
      define :awaiting_payment, title: "Won leads awaiting payment", kind: :leads do |scope, _|
        won = scope.leads.won
        won.where.not(id: Payment.select(:lead_id)).or(won.where(id: Payment.pending.select(:lead_id)))
      end

      define :instalments_due, title: "Instalments due in the next 7 days", kind: :installments do |scope, _|
        scope.installments.pending.where(due_on: Date.current..(Date.current + 7))
      end

      define :instalments_overdue, title: "Overdue instalments", kind: :installments do |scope, _|
        scope.installments.pending.where("due_on < ?", Date.current)
      end

      define :receipts_received, title: "Receipts", kind: :receipts, periodic: true do |scope, _|
        scope.receipts.where(received_on: scope.period.dates)
      end

      # Renewal Tickets / Renewal risk
      define :renewal_tickets, title: "Renewal tickets", kind: :tickets do |scope, _|
        scope.tickets.plan_expired.unfinished
      end

      define :renewal_risk, title: "Renewals at risk", kind: :subscriptions, roles: TEAM_ROLES do |scope, _|
        acted_on = AuditEvent.actions.where.not(action: "created").where(auditable_type: Ticket.name).select(:auditable_id)
        contacted = Ticket.plan_expired.where(id: acted_on)
                          .where("forefront_tickets.customer_id = forefront_subscriptions.customer_id")
                          .where("forefront_tickets.product_id = forefront_subscriptions.product_id")
        scope.subscriptions.where(expires_at: Date.current..(Date.current + 30))
             .where("NOT EXISTS (#{contacted.select('1').to_sql})")
      end
    end
  end
end
