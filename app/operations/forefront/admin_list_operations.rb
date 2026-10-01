module Forefront
  # Writes for the lists Admins maintain (see AdminList).
  module AdminListOperations
    class Create
      attr_reader :model, :params, :current_admin, :record, :errors

      def initialize(model:, params:, current_admin:)
        @model = model
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @record = model.new(params.slice(:name))

        if @record.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @record)
          { success: true, record: @record }
        else
          @errors = @record.errors.full_messages
          { success: false, record: @record, errors: @errors }
        end
      end
    end

    class Update
      attr_reader :record, :params, :current_admin, :errors

      def initialize(record:, params:, current_admin:)
        @record = record
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if record.update(params.slice(:name, :active))
          AuditEvent.record!(actor: current_admin, action: "updated", auditable: record) if record.saved_changes?
          { success: true, record: record }
        else
          @errors = record.errors.full_messages
          { success: false, record: record, errors: @errors }
        end
      end
    end

    class Destroy
      attr_reader :record, :current_admin, :errors

      def initialize(record:, current_admin:)
        @record = record
        @current_admin = current_admin
        @errors = []
      end

      def call
        if record.destroy
          AuditEvent.record!(actor: current_admin, action: "deleted", auditable: record, audited_changes: {})
          { success: true }
        else
          @errors = record.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end
