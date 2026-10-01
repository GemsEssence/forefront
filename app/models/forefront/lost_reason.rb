module Forefront
  # Why a Lead was lost (see CONTEXT.md). Always given with a written note.
  class LostReason < ApplicationRecord
    include AdminList
  end
end
