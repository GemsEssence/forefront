module Forefront
  module SettingsOperations
    class Update
      attr_reader :params, :current_admin, :settings, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @settings = Settings.current
        @settings.assign_attributes(params.slice(*Settings.attribute_names))
        changes = @settings.save

        if changes
          AuditEvent.record!(actor: current_admin, action: "updated_settings", auditable: nil, audited_changes: changes) if changes.any?
          { success: true, settings: @settings }
        else
          @errors = @settings.errors.full_messages
          { success: false, settings: @settings, errors: @errors }
        end
      end
    end
  end
end
