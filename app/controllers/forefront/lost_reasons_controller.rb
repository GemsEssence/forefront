module Forefront
  class LostReasonsController < AdminListsController
    private

    def list_model
      LostReason
    end

    def list_description
      "The reasons Staff choose from when a Lead is lost, always alongside a written note. Deactivate one to stop it being picked."
    end
  end
end
