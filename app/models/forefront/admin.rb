module Forefront
  class Admin < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :validatable

    enum :role, { admin: "admin", manager: "manager", sales_person: "sales_person" }

    belongs_to :manager, class_name: "Forefront::Admin", optional: true
    has_many :direct_reports, class_name: "Forefront::Admin", foreign_key: "manager_id", dependent: :nullify

    has_many :product_allocations, class_name: "Forefront::ProductAllocation", dependent: :destroy
    has_many :products, through: :product_allocations
    has_many :targets, class_name: "Forefront::Target", dependent: :destroy

    has_many :created_tickets, class_name: "Forefront::Ticket", foreign_key: "created_by_id", dependent: :nullify
    has_many :assigned_tickets, class_name: "Forefront::Ticket", foreign_key: "assigned_to_id", dependent: :nullify
    has_many :created_leads, class_name: "Forefront::Lead", foreign_key: "created_by_id", dependent: :nullify
    has_many :assigned_leads, class_name: "Forefront::Lead", foreign_key: "assigned_to_id", dependent: :nullify
    has_many :activities, class_name: "Forefront::Activity", foreign_key: "created_by_id", dependent: :destroy

    # Staff who can be given work; admins oversee rather than take tickets.
    scope :assignable, -> { where.not(role: "admin").order(:name) }
    # Real people, leaving out System.
    scope :people, -> { where(system: false) }

    validates :name, presence: true
    validates :role, presence: true
    validate :manager_is_not_self
    # validates :email, presence: true, uniqueness: true

    # System (CONTEXT.md): acts for automated inputs such as a Signup. It's
    # an Admin so its Tickets start unassigned, but it never signs in.
    def self.system_actor
      find_by(system: true) || create!(
        system: true, name: "System", role: "admin",
        email: "system-#{SecureRandom.hex(8)}@forefront.invalid", password: SecureRandom.base58(32)
      )
    end

    def active_for_authentication?
      super && !system?
    end

    # Refused like a wrong password, so nothing hints System could sign in.
    def inactive_message
      system? ? :invalid : super
    end

    # Kept so the many existing super_admin? call sites (policies, views) don't need renaming.
    def super_admin?
      admin?
    end

    def direct_report_ids
      direct_reports.pluck(:id)
    end

    # Leads this person holds that are neither Won nor Lost, which the cap
    # on taking from the pool counts.
    def unfinished_leads_count
      assigned_leads.where.not(status: %w[won lost]).count
    end

    private

    def manager_is_not_self
      errors.add(:manager, "can't be yourself") if manager_id.present? && manager_id == id
    end
  end
end
