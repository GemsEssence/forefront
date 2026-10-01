module Forefront
  class Lead < ApplicationRecord
    belongs_to :customer
    belongs_to :created_by, class_name: "Forefront::Admin"
    belongs_to :assigned_to, class_name: "Forefront::Admin", optional: true
    belongs_to :product, class_name: "Forefront::Product", optional: true
    belongs_to :source, class_name: "Forefront::Source"
    belongs_to :lost_reason, class_name: "Forefront::LostReason", optional: true
    has_many :activities, as: :actable, class_name: "Forefront::Activity", dependent: :destroy
    has_many :assignments, as: :assignable, class_name: 'Forefront::Assignment', dependent: :destroy
    has_many :status_histories, as: :trackable, class_name: 'Forefront::StatusHistory', dependent: :destroy
    has_many :followups, as: :followupable, class_name: 'Forefront::Followup', dependent: :destroy
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
    validate :product_allocated_to_sales_person

    before_save :set_won_at, if: :status_changed?
    before_save :forget_lost_reason, unless: :lost?
    # A stage change means the sale moved on, so it's no longer waiting.
    before_save -> { self.awaiting_customer_since = nil }, if: :will_save_change_to_status?
    after_save :ensure_subscription
    after_save :drop_subscription, if: -> { saved_change_to_status? && status_before_last_save == "won" }

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

    def ensure_subscription
      return unless won? && product.present? && expires_at.present?

      if subscription.present?
        subscription.update!(expires_at: expires_at) if subscription.expires_at != expires_at
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

    def product_allocated_to_sales_person
      return if product.nil? || assigned_to.nil?
      return unless assigned_to.sales_person?
      return if assigned_to.products.include?(product)

      errors.add(:product, "is not assigned to this sales person")
    end
  end
end

