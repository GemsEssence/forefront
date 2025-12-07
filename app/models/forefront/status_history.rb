module Forefront
  class StatusHistory < ApplicationRecord
    self.table_name = 'forefront_status_histories'

    belongs_to :trackable, polymorphic: true
    belongs_to :changed_by, class_name: 'Forefront::Admin'

    validates :new_status, presence: true
    validates :changed_by, presence: true
  end
end
