module Forefront
  class Admin < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :validatable

    has_many :created_tickets, class_name: "Forefront::Ticket", foreign_key: "created_by_id", dependent: :nullify
    has_many :assigned_tickets, class_name: "Forefront::Ticket", foreign_key: "assigned_to_id", dependent: :nullify
    has_many :created_leads, class_name: "Forefront::Lead", foreign_key: "created_by_id", dependent: :nullify
    has_many :assigned_leads, class_name: "Forefront::Lead", foreign_key: "assigned_to_id", dependent: :nullify

    validates :name, presence: true
    validates :email, presence: true, uniqueness: true
  end
end

