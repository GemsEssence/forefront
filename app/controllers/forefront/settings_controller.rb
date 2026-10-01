module Forefront
  class SettingsController < ApplicationController
    def show
      authorize Settings
      @settings = Settings.current
    end

    def update
      authorize Settings
      result = SettingsOperations::Update.new(params: settings_params, current_admin: current_admin).call

      if result[:success]
        redirect_to settings_path, notice: "Settings saved."
      else
        @settings = result[:settings]
        flash.now[:alert] = result[:errors].join(", ")
        render :show, status: :unprocessable_entity
      end
    end

    private

    def settings_params
      params.require(:settings).permit(*Settings.attribute_names)
    end
  end
end
