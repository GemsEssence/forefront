module Forefront
  class Assignment < ApplicationRecord
    belongs_to :assignable, polymorphic: true

    belongs_to :from_user, class_name: 'Forefront::Admin', optional: true
    belongs_to :to_user, class_name: 'Forefront::Admin'
    belongs_to :changed_by, class_name: 'Forefront::Admin', optional: true
  end
end
