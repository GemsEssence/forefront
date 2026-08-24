module Forefront
  class Admin < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :validatable

    enum :role, { admin: "admin", manager: "manager", sales_person: "sales_person" }

    belongs_to :manager, class_name: "Forefront::Admin", optional: true
    has_many :direct_reports, class_name: "Forefront::Admin", foreign_key: "manager_id", dependent: :nullify

    has_many :created_tickets, class_name: "Forefront::Ticket", foreign_key: "created_by_id", dependent: :nullify
    has_many :assigned_tickets, class_name: "Forefront::Ticket", foreign_key: "assigned_to_id", dependent: :nullify
    has_many :created_leads, class_name: "Forefront::Lead", foreign_key: "created_by_id", dependent: :nullify
    has_many :assigned_leads, class_name: "Forefront::Lead", foreign_key: "assigned_to_id", dependent: :nullify
    has_many :activities, class_name: "Forefront::Activity", foreign_key: "created_by_id", dependent: :destroy

    validates :name, presence: true
    validates :role, presence: true
    validate :manager_is_not_self
    # validates :email, presence: true, uniqueness: true

    # Kept so the many existing super_admin? call sites (policies, views) don't need renaming.
    def super_admin?
      admin?
    end

    def direct_report_ids
      direct_reports.pluck(:id)
    end

    private

    def manager_is_not_self
      errors.add(:manager, "can't be yourself") if manager_id.present? && manager_id == id
    end
  end
end
