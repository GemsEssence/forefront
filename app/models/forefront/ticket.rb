module Forefront
  class Ticket < ApplicationRecord
    belongs_to :customer
    belongs_to :created_by, class_name: "Forefront::Admin"
    belongs_to :assigned_to, class_name: "Forefront::Admin", optional: true
    has_many :activities, as: :actable, class_name: "Forefront::Activity", dependent: :destroy
    has_many :assignments, as: :assignable, class_name: 'Forefront::Assignment', dependent: :destroy

    enum category: {
      tech: 'Tech',
      issue: 'Issue',
      request: 'Request',
      complaint: 'Complaint',
      demo: 'Demo',
      plan_expired: 'Plan Expired',
      regular_call: 'Regular Call',
      new_requirement: 'New Requirement',
      suggestion: 'Suggestion',
      white_label_app: 'White Label App'
    }

    enum priority: {
      low: 'Low',
      medium: 'Medium',
      high: 'High',
      critical: 'Critical'
    }

    enum status: {
      new: 'New',
      open: 'Open',
      in_progress: 'In Progress',
      on_hold: 'On Hold',
      waiting_customer: 'Waiting Customer',
      resolved: 'Resolved',
      closed: 'Closed'
    }

    validates :title, presence: true
    validates :description, presence: true
    validates :category, presence: true
    validates :priority, presence: true
    validates :status, presence: true

    # Scopes for filtering
    scope :by_category, ->(category) { where(category: category) }
    scope :by_priority, ->(priority) { where(priority: priority) }
    scope :by_status, ->(status) { where(status: status) }
    scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
    scope :by_created_by, ->(admin_id) { where(created_by_id: admin_id) }
    scope :by_assigned_to, ->(admin_id) { where(assigned_to_id: admin_id) }
    scope :overdue, -> { where("due_at < ? AND status NOT IN (?)", Date.current, ['Resolved', 'Closed']) }
    scope :due_soon, -> { where("due_at BETWEEN ? AND ? AND status NOT IN (?)", Date.current, 1.day.from_now, ['Resolved', 'Closed']) }
    scope :needs_followup, -> { where("next_followup_at <= ? AND status NOT IN (?)", Time.current, ['resolved', 'closed']) }
    scope :recent, -> { order(created_at: :desc) }
    scope :by_due_date, -> { order(due_at: :asc) }

    def overdue?
      due_at.present? && due_at < Date.current && !resolved? && !closed?
    end

    def due_soon?
      due_at.present? && due_at.between?(Date.current, 1.day.from_now) && !resolved? && !closed?
    end

    def needs_followup?
      next_followup_at.present? && next_followup_at <= Time.current && !resolved? && !closed?
    end
  end
end

