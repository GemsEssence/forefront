module Forefront
  class Activity < ApplicationRecord
    belongs_to :actable, polymorphic: true
    belongs_to :created_by, class_name: "Forefront::Admin"

    enum activity_type: {
      comment: 'comment',
      remark: 'remark',
      next_step: 'next_step',
      internal_note: 'internal_note'
    }

    validates :body, presence: true
    validates :activity_type, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :by_type, ->(type) { where(activity_type: type) }
  end
end

