module Forefront
  class SourcesController < AdminListsController
    private

    def list_model
      Source
    end

    def list_description
      "Where Leads come from and where Campaigns run. Deactivate a Source to stop it being picked; Leads that already use it keep it."
    end
  end
end
