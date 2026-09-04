module Forefront
  class Lead < ApplicationRecord
    belongs_to :customer
    belongs_to :created_by, class_name: "Forefront::Admin"
    belongs_to :assigned_to, class_name: "Forefront::Admin", optional: true
    belongs_to :product, class_name: "Forefront::Product", optional: true
    has_many :activities, as: :actable, class_name: "Forefront::Activity", dependent: :destroy
    has_many :assignments, as: :assignable, class_name: 'Forefront::Assignment', dependent: :destroy
    has_many :status_histories, as: :trackable, class_name: 'Forefront::StatusHistory', dependent: :destroy
    has_many :followups, as: :followupable, class_name: 'Forefront::Followup', dependent: :destroy
    has_one :payment, class_name: "Forefront::Payment", dependent: :destroy

    enum :source, {
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

    enum :status, {
      open: 'Open',
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
    validate :product_allocated_to_sales_person

    before_save :set_won_at, if: :status_changed?

    # Scopes for filtering
    scope :by_source, ->(source) { where(source: source) }
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

    private

    def set_won_at
      self.won_at = won? ? (won_at || Time.current) : nil
    end

    def product_allocated_to_sales_person
      return if product.nil? || assigned_to.nil?
      return unless assigned_to.sales_person?
      return if assigned_to.products.include?(product)

      errors.add(:product, "is not assigned to this sales person")
    end
  end
end

