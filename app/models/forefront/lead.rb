module Forefront
  class Lead < ApplicationRecord
    belongs_to :customer
    belongs_to :created_by, class_name: "Forefront::Admin"
    belongs_to :assigned_to, class_name: "Forefront::Admin", optional: true
    has_many :activities, as: :actable, class_name: "Forefront::Activity", dependent: :destroy

    enum source: {
      website: 'Website',
      phone: 'Phone',
      email: 'Email',
      referral: 'Referral',
      linkedin: 'Linkedin',
      upwork: 'Upwork',
      freelancer: 'Freelancer',
      gitex: 'Gitex',
      india_soft: 'India Soft',
      event: 'Event',
      other: 'Other'
    }

    enum status: {
      new: 'New',
      contacted: 'Contacted',
      follow_up: 'Follow Up',
      proposal: 'Proposal',
      negotiation: 'Negotiation',
      nda_signed: 'NDA Signed',
      won: 'Won',
      lost: 'Lost'
    }

    validates :title, presence: true
    validates :description, presence: true
    validates :source, presence: true
    validates :status, presence: true

    # Scopes for filtering
    scope :by_source, ->(source) { where(source: source) }
    scope :by_status, ->(status) { where(status: status) }
    scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
    scope :by_created_by, ->(admin_id) { where(created_by_id: admin_id) }
    scope :by_assigned_to, ->(admin_id) { where(assigned_to_id: admin_id) }
    scope :overdue, -> { where("due_at < ? AND status NOT IN (?)", Date.current, ['Won', 'Lost']) }
    scope :due_soon, -> { where("due_at BETWEEN ? AND ? AND status NOT IN (?)", Date.current, 1.day.from_now, ['Won', 'Lost']) }
    scope :needs_followup, -> { where("next_followup_at <= ? AND status NOT IN (?)", Time.current, ['won', 'lost']) }
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
  end
end

