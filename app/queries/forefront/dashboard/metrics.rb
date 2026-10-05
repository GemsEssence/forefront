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
        raise ArgumentError, "Metric #{key} is already defined" if @registry.key?(key.to_s)

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

      # Only those whose time has come: one scheduled later isn't a miss yet.
      define :followups_due, title: "Followups due", kind: :followups, periodic: true do |scope, _|
        scope.followups.where(scheduled_for: scope.period.times).where("scheduled_for <= ?", Time.current).where.not(status: "cancelled")
      end

      # Completed by the end of the scheduled day (compared in Ruby: portable SQL).
      define :followups_on_time, title: "Followups done on time", kind: :followups, periodic: true do |scope, _|
        due = fetch(:followups_due).relation(scope).where.not(completed_at: nil)
        on_time = due.pluck(:id, :scheduled_for, :completed_at).select { |_, scheduled, done| done <= scheduled.end_of_day }.map(&:first)
        Followup.where(id: on_time)
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

      define :receipts_received, title: "Receipts", kind: :receipts, periodic: true do |scope, kind|
        receipts = scope.receipts.where(received_on: scope.period.dates)
        case kind
        when nil then receipts
        when "one_off" then receipts.where(installment_id: nil)
        when "instalment" then receipts.where.not(installment_id: nil)
        else receipts.none
        end
      end

      # Renewal Tickets / Renewal risk
      define :renewal_tickets, title: "Renewal tickets", kind: :tickets do |scope, _|
        scope.tickets.renewal.unfinished
      end

      # A renewal moves the same Subscription's expires_at (CONTEXT.md), so only
      # an unfinished renewal ticket someone acted on covers this cycle; a
      # resolved one from the last cycle doesn't.
      define :renewal_risk, title: "Renewals at risk", kind: :subscriptions, roles: TEAM_ROLES do |scope, _|
        acted_on = AuditEvent.actions.where.not(action: "created").where(auditable_type: Ticket.name).select(:auditable_id)
        tickets, subscriptions = Ticket.table_name, Subscription.table_name
        contacted = Ticket.renewal.unfinished.where(id: acted_on)
                          .where("#{tickets}.customer_id = #{subscriptions}.customer_id")
                          .where("#{tickets}.product_id = #{subscriptions}.product_id")
        scope.subscriptions.where(expires_at: Date.current..(Date.current + 30))
             .where("NOT EXISTS (#{contacted.select('1').to_sql})")
      end

      # My activity / Performance per person
      ACTIVITY = %i[demos proposals conversions won lost].freeze

      def self.moved_into(scope, stage, by_people:)
        moves = StatusHistory.where(trackable_type: Lead.name, new_status: Lead.statuses.fetch(stage), created_at: scope.period.times)
        moves = by_people && scope.people_ids ? moves.where(changed_by_id: scope.people_ids) : moves
        leads = by_people ? (scope.product_id ? Lead.where(product_id: scope.product_id) : nil) : scope.leads
        leads ? moves.where(trackable_id: leads.select(:id)) : moves
      end

      define :demos, title: "Demos given", kind: :status_histories, periodic: true do |scope, _|
        moved_into(scope, "demo", by_people: true)
      end

      define :proposals, title: "Proposals sent", kind: :status_histories, periodic: true do |scope, _|
        moved_into(scope, "proposal", by_people: true)
      end

      define :conversions, title: "Tickets converted to leads", kind: :audit_events, periodic: true do |scope, _|
        events = AuditEvent.where(action: "converted", auditable_type: Ticket.name, created_at: scope.period.times)
        events = events.where(actor_id: scope.people_ids) if scope.people_ids
        scope.product_id ? events.where(auditable_id: Ticket.where(product_id: scope.product_id).select(:id)) : events
      end

      define :won, title: "Leads won", kind: :leads, periodic: true do |scope, _|
        scope.leads.won.where(won_at: scope.period.times)
      end

      define :lost, title: "Leads lost", kind: :status_histories, periodic: true do |scope, _|
        moved_into(scope, "lost", by_people: false)
      end

      # Unassigned pool
      AGES = { "under_2h" => [ 0.hours, 2.hours ], "2h_24h" => [ 2.hours, 24.hours ], "1d_3d" => [ 24.hours, 72.hours ], "over_3d" => [ 72.hours, nil ] }.freeze

      def self.aged(relation, bucket)
        return relation if bucket.nil?
        return relation.none unless AGES.key?(bucket)

        newest, oldest = AGES.fetch(bucket)
        table = relation.klass.table_name
        relation = relation.where("#{table}.created_at <= ?", newest.ago)
        oldest ? relation.where("#{table}.created_at > ?", oldest.ago) : relation
      end

      def self.pool(scope, model)
        work = model == Lead ? Lead.active : Ticket.unfinished
        pool = UnassignedPool.visible_to(scope.viewer, work)
        scope.product_id ? pool.where(product_id: scope.product_id) : pool
      end

      define :pool_leads, title: "Unassigned leads", kind: :leads, roles: TEAM_ROLES do |scope, bucket|
        aged(pool(scope, Lead), bucket)
      end

      define :pool_tickets, title: "Unassigned tickets", kind: :tickets, roles: TEAM_ROLES do |scope, bucket|
        aged(pool(scope, Ticket), bucket)
      end

      define :pool_leads_by_source, title: "Unassigned leads by source", kind: :leads, roles: TEAM_ROLES do |scope, source_id|
        source_id ? pool(scope, Lead).where(source_id: source_id) : pool(scope, Lead)
      end

      # Workload per person
      define :open_tickets, title: "Open tickets", kind: :tickets do |scope, _|
        scope.tickets.unfinished
      end

      define :active_leads, title: "Open leads", kind: :leads do |scope, _|
        scope.leads.active
      end

      # Leads by source / Source ROI
      define :source_leads, title: "Leads created", kind: :leads, periodic: true do |scope, source_id|
        leads = scope.leads.where(created_at: scope.period.times)
        source_id ? leads.where(source_id: source_id) : leads
      end

      define :source_won, title: "Leads created and now won", kind: :leads, periodic: true do |scope, source_id|
        fetch(:source_leads).relation(scope, source_id).won
      end

      # Subscriptions / Data health (Company)
      define :subscriptions, title: "Subscriptions", kind: :subscriptions, roles: %w[admin] do |scope, state|
        subscriptions = scope.subscriptions
        today = Date.current
        case state
        when "active" then subscriptions.where("expires_at > ?", today + 30)
        when "expiring" then subscriptions.where(expires_at: today..(today + 30))
        when "expired" then subscriptions.where("expires_at < ?", today)
        else subscriptions.none
        end
      end

      define :failed_intake, title: "Rejected Signup API calls", kind: :audit_events, roles: %w[admin], periodic: true do |scope, _|
        events = AuditEvent.where(action: "rejected_signup", created_at: scope.period.times)
        scope.product_id ? events.where(auditable_type: Product.name, auditable_id: scope.product_id) : events
      end

      # Performance
      # Taken from the pool: no previous assignee, assigned to themselves, on
      # a Ticket or Lead someone else created (your own records are never claims).
      def self.claims(scope)
        table = Assignment.table_name
        created_it = lambda do |model|
          "NOT EXISTS (SELECT 1 FROM #{model.table_name} WHERE #{model.table_name}.id = #{table}.assignable_id " \
            "AND #{table}.assignable_type = #{Assignment.connection.quote(model.name)} " \
            "AND #{model.table_name}.created_by_id = #{table}.to_user_id)"
        end
        scope.assignments.where(from_user_id: nil).where("#{table}.changed_by_id = #{table}.to_user_id")
             .where(created_at: scope.period.times).where(created_it.call(Lead)).where(created_it.call(Ticket))
      end

      define :claims, title: "Records claimed", kind: :assignments, periodic: true do |scope, _|
        claims(scope)
      end

      ENQUIRY_CATEGORIES = %w[enquiry signup].freeze

      def self.enquiries(scope)
        scope.tickets.where(category: ENQUIRY_CATEGORIES)
      end

      def self.converted_ticket_ids(scope)
        AuditEvent.where(action: "converted", auditable_type: Ticket.name, created_at: scope.period.times).select(:auditable_id)
      end

      define :enquiries_converted, title: "Enquiries converted to leads", kind: :tickets, periodic: true do |scope, _|
        enquiries(scope).where(id: converted_ticket_ids(scope))
      end

      # Converted in the period, or finished in the period without ever being converted.
      define :enquiries_handled, title: "Enquiries handled", kind: :tickets, periodic: true do |scope, _|
        finished = StatusHistory.where(trackable_type: Ticket.name, created_at: scope.period.times,
                                       new_status: [ Ticket.statuses.fetch("resolved"), Ticket.statuses.fetch("closed") ]).select(:trackable_id)
        ever_converted = AuditEvent.where(action: "converted", auditable_type: Ticket.name).where.not(auditable_id: nil).select(:auditable_id)
        enquiries(scope).where(id: converted_ticket_ids(scope))
                        .or(enquiries(scope).where(id: finished).where.not(id: ever_converted))
      end

      define :leads_lost, title: "Leads lost", kind: :leads, periodic: true do |scope, reason_id|
        lost = scope.leads.where(id: StatusHistory.where(trackable_type: Lead.name, new_status: Lead.statuses.fetch("lost"),
                                                         created_at: scope.period.times).select(:trackable_id))
        reason_id ? lost.where(lost_reason_id: reason_id) : lost
      end

      define :leads_closed, title: "Leads closed (won or lost)", kind: :leads, periodic: true do |scope, _|
        fetch(:won).relation(scope).or(scope.leads.where(id: fetch(:leads_lost).relation(scope).select(:id)))
      end

      # Leads the people in view have credit for: their own unshared Leads,
      # and shared Leads they take part in.
      def self.credited_leads(scope)
        leads = Lead.all
        if scope.people_ids
          shared = LeadShare.select(:lead_id)
          taking_part = LeadShareParticipant.joins(:lead_share).where(admin_id: scope.people_ids).select("#{LeadShare.table_name}.lead_id")
          leads = Lead.where(assigned_to_id: scope.people_ids).where.not(id: shared).or(Lead.where(id: taking_part))
        end
        scope.product_id ? leads.where(product_id: scope.product_id) : leads
      end

      define :target_credited, title: "Won leads counted towards running targets", kind: :leads do |scope, _|
        Lead.where(id: scope.current_targets.select(&:amount?).flat_map { |target| target.credited_leads.ids })
      end

      define :receipts_credited, title: "Receipts credited", kind: :receipts, periodic: true do |scope, _|
        Receipt.where(received_on: scope.period.dates, payment_id: Payment.where(lead_id: credited_leads(scope).select(:id)).select(:id))
      end

      define :receipts_shared, title: "Receipts from shared leads", kind: :receipts, periodic: true do |scope, _|
        fetch(:receipts_credited).relation(scope).where(payment_id: Payment.where(lead_id: LeadShare.select(:lead_id)).select(:id))
      end

      # Only those whose date has come: one due later isn't a miss yet.
      define :instalments_due_in_period, title: "Instalments due", kind: :installments, periodic: true do |scope, _|
        scope.installments.where(due_on: scope.period.dates).where(due_on: ..Date.current)
      end

      # Paid by the due date (compared in Ruby: portable SQL).
      define :instalments_on_time, title: "Instalments paid on time", kind: :installments, periodic: true do |scope, _|
        paid = fetch(:instalments_due_in_period).relation(scope).where.not(paid_at: nil)
        Installment.where(id: paid.pluck(:id, :due_on, :paid_at).select { |_, due, paid_at| paid_at.to_date <= due }.map(&:first))
      end

      define :renewals_closed, title: "Renewal tickets closed", kind: :tickets, periodic: true do |scope, _|
        finished = StatusHistory.where(trackable_type: Ticket.name, created_at: scope.period.times,
                                       new_status: [ Ticket.statuses.fetch("resolved"), Ticket.statuses.fetch("closed") ]).select(:trackable_id)
        scope.tickets.renewal.where(id: finished).where.not(renewal_outcome: nil)
      end

      define :renewals_renewed, title: "Renewal tickets renewed", kind: :tickets, periodic: true do |scope, _|
        fetch(:renewals_closed).relation(scope).renewed
      end
    end
  end
end
