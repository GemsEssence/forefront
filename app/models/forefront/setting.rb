module Forefront
  # One stored setting; read and written through Forefront::Settings.
  class Setting < ApplicationRecord
    validates :key, presence: true, uniqueness: true
  end
end
