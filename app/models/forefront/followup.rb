module Forefront
  class Followup < ApplicationRecord
    belongs_to :followupable, polymorphic: true
    belongs_to :assigned_to, class_name: 'Forefront::Admin', optional: true
    belongs_to :created_by, class_name: 'Forefront::Admin'

    enum :followup_type, {
      call: 'Call',
      email: 'Email',
      meeting: 'Meeting',
      demo: 'Demo',
      other: 'Other'
    }

    enum :status, {
      pending: 'Pending',
      completed: 'Completed',
      cancelled: 'Cancelled'
    }, default: :pending # the column's DB default ("pending") isn't one of these stored values
    
    validates :assigned_to, :followup_type, :scheduled_for, :status, presence: true

    scope :upcoming, -> { where(status: 'pending').where('scheduled_for >= ?', Time.current).order(:scheduled_for) }
    scope :pending, -> { where(status: 'pending') }
  end
end
