module Forefront
  class StatusHistory < ApplicationRecord
    belongs_to :trackable, polymorphic: true
    belongs_to :changed_by, class_name: 'Forefront::Admin'

    validates :new_status, presence: true
  end
end
