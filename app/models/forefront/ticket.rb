module Forefront
  class Ticket < ApplicationRecord
    belongs_to :customer
    belongs_to :created_by, class_name: "Forefront::Admin"
    belongs_to :assigned_to, class_name: "Forefront::Admin", optional: true
    belongs_to :product, class_name: "Forefront::Product", optional: true
    belongs_to :lead, class_name: "Forefront::Lead", optional: true
    belongs_to :campaign, class_name: "Forefront::Campaign", optional: true
    has_many :activities, as: :actable, class_name: "Forefront::Activity", dependent: :destroy
    has_many :assignments, as: :assignable, class_name: 'Forefront::Assignment', dependent: :destroy
    has_many :status_histories, as: :trackable, class_name: 'Forefront::StatusHistory', dependent: :destroy
    has_many :followups, as: :followupable, class_name: 'Forefront::Followup', dependent: :destroy
    has_many :notifications, as: :subject, class_name: "Forefront::Notification", dependent: :delete_all

    enum :category, {
      tech: "Tech",
      issue: "Issue",
      request: "Request",
      complaint: "Complaint",
      new_app_demo: "New App Demo",
      proposal: "Proposal",
      signup: "Signup",
      enquiry: "Enquiry",
      regular_call: "Regular Call",
      new_requirement: "New Requirement",
      suggestion: "Suggestion",
      white_label_app: "White Label App",
      support_call: "Support Call",
      support_demo: "Support Demo",
      renewal: "Renewal"
    }

    enum :priority, {
      low: 'Low',
      medium: 'Medium',
      high: 'High',
      critical: 'Critical'
    }

    enum :status, {
      open: 'Open',
      in_progress: 'In Progress',
      on_hold: 'On Hold',
      waiting_customer: 'Waiting Customer',
      resolved: 'Resolved',
      closed: 'Closed'
    }

    enum :renewal_outcome, { renewed: "renewed", declined: "declined" }

    validates :title, presence: true
    validates :description, presence: true
    validates :category, presence: true
    validates :priority, presence: true
    validates :status, presence: true
    validate :assignee_is_not_an_admin, if: :will_save_change_to_assigned_to_id?
    validate :matches_its_lead, if: :lead

    # Scopes for filtering
    scope :by_category, ->(category) { where(category: category) }
    scope :by_priority, ->(priority) { where(priority: priority) }
    scope :by_status, ->(status) { where(status: status) }
    scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
    scope :by_created_by, ->(admin_id) { where(created_by_id: admin_id) }
    scope :by_assigned_to, ->(admin_id) { where(assigned_to_id: admin_id) }
    scope :overdue, -> { where("due_at < ? AND status NOT IN (?)", Date.current, ['Resolved', 'Closed']) }
    scope :due_soon, -> { where("due_at BETWEEN ? AND ? AND status NOT IN (?)", Date.current, 1.day.from_now, ['Resolved', 'Closed']) }
    scope :needs_followup, -> { where("next_followup_at <= ? AND status NOT IN (?)", Time.current, ['Resolved', 'Closed']) }
    scope :recent, -> { order(created_at: :desc) }
    scope :by_due_date, -> { order(due_at: :asc) }
    scope :unfinished, -> { where.not(status: %w[resolved closed]) }

    # A demo or Proposal under a Lead: resolving it asks what's next for the Lead.
    def lead_work?
      lead.present? && (new_app_demo? || proposal?)
    end

    # Work that can become a Lead: not already one's, not a renewal (that's
    # about a Subscription), and not finished.
    def convertible?
      lead_id.nil? && !renewal? && !resolved? && !closed?
    end

    # The Source a Lead converted from this Ticket starts with.
    def conversion_source
      campaign&.source || (Source.signup if signup?)
    end

    def resolved_at
      status_histories.where(new_status: "Resolved").maximum(:created_at) || updated_at
    end

    def overdue?
      due_at.present? && due_at < Date.current && !resolved? && !closed?
    end

    def due_soon?
      due_at.present? && due_at.between?(Date.current, 1.day.from_now) && !resolved? && !closed?
    end

    def needs_followup?
      next_followup_at.present? && next_followup_at <= Time.current && !resolved? && !closed?
    end

    # For a renewal Ticket: when the Customer's Subscription to this Product runs out.
    def subscription_expires_on
      return if product_id.nil?

      Subscription.where(customer_id: customer_id, product_id: product_id).maximum(:expires_at)
    end

    def renewal_reward_amount
      return 0 unless renewal? && renewed? && product.present?
      return 0 if product.renewal_reward_percentage.blank?

      subscription = customer.subscriptions.find_by(product_id: product_id)
      return 0 if subscription.blank?

      payment = subscription.lead.payment
      return 0 if payment.blank?

      product.renewal_reward_percentage / 100.0 * payment.total_amount
    end

    private

    # Work under a Lead is about that Lead's sale; a renewal is about a
    # Subscription instead (ADR 0003), and support work is for a Customer who
    # already has the Product, so neither ever sits under a Lead.
    def matches_its_lead
      errors.add(:customer, "must be the lead's customer") if customer_id != lead.customer_id
      errors.add(:product, "must be the lead's product") if product_id != lead.product_id
      errors.add(:base, "A renewal ticket can't belong to a lead") if renewal?
      errors.add(:base, "A support ticket can't belong to a lead") if support_demo? || support_call?
    end

    def assignee_is_not_an_admin
      errors.add(:assigned_to, "can't be an admin") if assigned_to&.admin?
    end
  end
end
