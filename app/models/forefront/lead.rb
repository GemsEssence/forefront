module Forefront
  class Lead < ApplicationRecord
    belongs_to :customer
    belongs_to :created_by, class_name: "Forefront::Admin"
    belongs_to :assigned_to, class_name: "Forefront::Admin", optional: true
    belongs_to :product, class_name: "Forefront::Product", optional: true
    belongs_to :source, class_name: "Forefront::Source"
    belongs_to :lost_reason, class_name: "Forefront::LostReason", optional: true
    belongs_to :campaign, class_name: "Forefront::Campaign", optional: true
    has_many :activities, as: :actable, class_name: "Forefront::Activity", dependent: :destroy
    has_many :assignments, as: :assignable, class_name: 'Forefront::Assignment', dependent: :destroy
    has_many :status_histories, as: :trackable, class_name: 'Forefront::StatusHistory', dependent: :destroy
    has_many :followups, as: :followupable, class_name: 'Forefront::Followup', dependent: :destroy
    has_many :notifications, as: :subject, class_name: "Forefront::Notification", dependent: :delete_all
    has_one :payment, class_name: "Forefront::Payment", dependent: :destroy
    has_one :subscription, class_name: "Forefront::Subscription", dependent: :destroy
    has_one :lead_share, class_name: "Forefront::LeadShare", dependent: :destroy
    has_many :tickets, class_name: "Forefront::Ticket", dependent: :nullify

    # The Lead's stage (CONTEXT.md): how far the sale has got. Changed only
    # through the stage dialog (StatusHistoryOperations), never the edit form.
    enum :status, {
      open: "Open",
      contacted: "Contacted",
      demo: "Demo",
      proposal: "Proposal",
      negotiation: "Negotiation",
      won: "Won",
      lost: "Lost"
    }

    validates :title, presence: true
    validates :description, presence: true
    validates :estimated_amount, :actual_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    # The deal can close for a different figure than estimated, so winning a
    # Lead asks for what it actually closed for (Targets count this).
    validates :actual_amount, presence: true, if: -> { won? && will_save_change_to_status? }
    validate :source_is_active, if: :will_save_change_to_source_id?
    validate :agreement_only_for_white_label
    validate :lost_with_reason_and_note, if: -> { lost? && will_save_change_to_status? }
    validate :awaiting_only_while_worked, if: -> { awaiting_customer? && will_save_change_to_awaiting_customer_since? }
    validate :paid_win_is_final, if: -> { will_save_change_to_status? && status_in_database == "won" }
    validates :status, presence: true
    validate :assignee_is_not_an_admin, if: :will_save_change_to_assigned_to_id?
    validate :private_lead_is_assigned, if: :private?
    validate :product_allocated_to_sales_person
    validate :only_unfinished_lead_for_its_product, if: -> { product_id.present? && active? && (new_record? || will_save_change_to_status? || will_save_change_to_customer_id? || will_save_change_to_product_id?) }

    before_save :set_won_at, if: :status_changed?
    # A Private Lead (CONTEXT.md) stays private only while it's being worked.
    before_save -> { self.private = false }, if: -> { private? && (won? || lost?) }
    before_save :forget_lost_reason, unless: :lost?
    # A stage change means the sale moved on, so it's no longer waiting.
    before_save -> { self.awaiting_customer_since = nil }, if: :will_save_change_to_status?
    after_save :ensure_subscription
    after_save :drop_subscription, if: -> { saved_change_to_status? && status_before_last_save == "won" }

    # The Leads this person may know about: everything for an Admin; for
    # anyone else, all but the Private Leads of other people (CONTEXT.md).
    scope :visible_to, lambda { |admin|
      next all if admin.admin?

      where(private: false).or(where(created_by_id: admin.id)).or(where(assigned_to_id: admin.id))
    }

    # Scopes for filtering
    scope :by_source, ->(source_id) { where(source_id: source_id) }
    scope :by_status, ->(status) { where(status: status) }
    scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
    scope :by_created_by, ->(admin_id) { where(created_by_id: admin_id) }
    scope :by_assigned_to, ->(admin_id) { where(assigned_to_id: admin_id) }
    scope :overdue, -> { where("due_at < ? AND status NOT IN (?)", Date.current, ['Won', 'Lost']) }
    scope :due_soon, -> { where("due_at BETWEEN ? AND ? AND status NOT IN (?)", Date.current, 1.day.from_now, ['Won', 'Lost']) }
    scope :needs_followup, -> { where("next_followup_at <= ? AND status NOT IN (?)", Time.current, ['Won', 'Lost']) }
    scope :active, -> { where.not(status: ['won', 'lost']) }
    scope :won, -> { where(status: 'won') }
    scope :lost, -> { where(status: 'lost') }
    scope :recent, -> { order(created_at: :desc) }
    scope :by_due_date, -> { order(due_at: :asc) }

    def overdue?
      due_at.present? && due_at < Date.current && !won? && !lost?
    end

    def due_soon?
      due_at.present? && due_at.between?(Date.current, 1.day.from_now) && !won? && !lost?
    end

    def needs_followup?
      next_followup_at.present? && next_followup_at <= Time.current && !won? && !lost?
    end

    def active?
      !won? && !lost?
    end

    # Who may be handed this Lead: Sales persons allocated its Product, and
    # Managers. Admins oversee rather than carry Leads (CONTEXT.md). A Lead
    # from before Products were required has no allocation to go by, so only
    # Managers qualify.
    def eligible_assignees
      people = Admin.people.where.not(system: true)
      sales = product ? people.where(role: "sales_person", id: product.admin_ids) : people.none
      people.where(role: "manager").or(sales).order(:name)
    end

    # Who may be named in this Lead's share: anyone who could hold it, plus
    # anyone who ever did.
    def share_candidates
      Admin.where(id: eligible_assignees.select(:id)).or(Admin.where(id: past_assignees.select(:id))).where.not(role: "admin").order(:name)
    end

    # The Customer's other Leads for this Product, newest first.
    def sibling_leads
      Lead.where(customer_id: customer_id, product_id: product_id).where.not(id: id).order(created_at: :desc)
    end

    def blocking_message_for(other)
      if other.active?
        "#{customer.name} already has an unfinished lead for #{product.name}: #{other.title}"
      else
        "#{customer.name}'s lead for #{product.name} was lost: #{other.title}. Ask a Manager to reopen it"
      end
    end

    STAGE_WORK_DONE = { "new_app_demo" => "Demo done", "proposal" => "Proposal sent" }.freeze

    # [["Demo done", time], ...] for the stage work under this Lead that's
    # been finished, so the page shows how far the sale really got.
    def stage_work_done
      STAGE_WORK_DONE.filter_map do |category, label|
        ticket = tickets.where(category: category, status: "resolved").order(:updated_at).last
        [ label, ticket.resolved_at ] if ticket
      end
    end

    def awaiting_customer?
      awaiting_customer_since.present?
    end

    def next_followup
      followups.pending.order(:scheduled_for).first
    end

    def past_assignees
      ids = assignments.pluck(:to_user_id)
      ids << assigned_to_id if assigned_to_id.present?
      Admin.where(id: ids.uniq)
    end

    def share_fraction_for(admin_id)
      if lead_share.present?
        participant = lead_share.lead_share_participants.find_by(admin_id: admin_id)
        participant ? participant.percentage / 100.0 : 0
      elsif assigned_to_id == admin_id
        1.0
      else
        0
      end
    end

    def reclaim?
      return false if product.blank?

      customer.subscriptions
              .where(product_id: product_id)
              .where.not(lead_id: id)
              .where("expires_at <= ?", 3.months.ago.to_date)
              .exists?
    end

    def reclaim_reward_amount
      return 0 unless won? && reclaim?
      return 0 if product.reclaim_reward_percentage.blank?
      return 0 if payment.blank?

      product.reclaim_reward_percentage / 100.0 * payment.total_amount
    end

    def reclaim_reward_amount_for(admin_id)
      reclaim_reward_amount * share_fraction_for(admin_id)
    end

    private

    def set_won_at
      self.won_at = won? ? (won_at || Time.current) : nil
    end

    # The Subscription's expires_at is the one that moves (CONTEXT.md), by
    # the Expiry pull; the Lead's only sets it, or resets it when edited.
    def ensure_subscription
      return unless won? && product.present? && expires_at.present?

      if subscription.present?
        subscription.update!(expires_at: expires_at) if saved_change_to_expires_at? && subscription.expires_at != expires_at
      else
        create_subscription!(customer: customer, product: product, expires_at: expires_at)
      end
    end

    # A reason alone never explains a loss, so a note always goes with it.
    def lost_with_reason_and_note
      if lost_reason.nil?
        errors.add(:lost_reason, "must be chosen")
      elsif !lost_reason.active? && will_save_change_to_lost_reason_id?
        errors.add(:lost_reason, "is no longer in use")
      end
      errors.add(:base, "Note is required when a lead is lost") if lost_note.blank?
    end

    def awaiting_only_while_worked
      errors.add(:base, "Only a lead still being worked can be awaiting the customer") unless active?
    end

    # Once money is recorded against the sale, the win can't be taken back.
    def paid_win_is_final
      errors.add(:base, "A won lead with a payment recorded can't change stage") if payment.present?
    end

    # An undone win never was a sale, so it no longer gives the Customer a
    # Subscription to renew.
    def drop_subscription
      subscription&.destroy!
      reset_subscription
    end

    def forget_lost_reason
      self.lost_reason = nil
      self.lost_note = nil
    end

    def agreement_only_for_white_label
      return if white_label? || agreement_signed_on.blank?

      errors.add(:agreement_signed_on, "can only be set for a white-label lead")
    end

    # A deactivated Source stays on the Leads that already have it, but can't
    # be picked for a new Lead or switched to.
    def source_is_active
      errors.add(:source, "is no longer in use") if source && !source.active?
    end

    # A Customer has at most one unfinished Lead per Product (CONTEXT.md).
    def only_unfinished_lead_for_its_product
      other = sibling_leads.find(&:active?)
      errors.add(:base, blocking_message_for(other)) if other
    end

    # A Private Lead is never in the pool: nobody could find it there.
    def private_lead_is_assigned
      errors.add(:base, "A private lead must be assigned") if assigned_to_id.nil?
    end

    # Admins oversee rather than carry Leads (CONTEXT.md).
    def assignee_is_not_an_admin
      errors.add(:assigned_to, "can't be an admin") if assigned_to&.admin?
    end

    def product_allocated_to_sales_person
      return if product.nil? || assigned_to.nil?
      return unless assigned_to.sales_person?
      return if assigned_to.products.include?(product)

      errors.add(:product, "is not assigned to this sales person")
    end
  end
end

