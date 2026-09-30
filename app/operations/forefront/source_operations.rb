module Forefront
  module SourceOperations
    class Create
      attr_reader :params, :current_admin, :source, :errors

      def initialize(params:, current_admin:)
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        @source = Source.new(params.slice(:name))

        if @source.save
          AuditEvent.record!(actor: current_admin, action: "created", auditable: @source)
          { success: true, source: @source }
        else
          @errors = @source.errors.full_messages
          { success: false, source: @source, errors: @errors }
        end
      end
    end

    class Update
      attr_reader :source, :params, :current_admin, :errors

      def initialize(source:, params:, current_admin:)
        @source = source
        @params = params
        @current_admin = current_admin
        @errors = []
      end

      def call
        if source.update(params.slice(:name, :active))
          AuditEvent.record!(actor: current_admin, action: "updated", auditable: source) if source.saved_changes?
          { success: true, source: source }
        else
          @errors = source.errors.full_messages
          { success: false, source: source, errors: @errors }
        end
      end
    end

    class Destroy
      attr_reader :source, :current_admin, :errors

      def initialize(source:, current_admin:)
        @source = source
        @current_admin = current_admin
        @errors = []
      end

      def call
        if source.destroy
          AuditEvent.record!(actor: current_admin, action: "deleted", auditable: source, audited_changes: {})
          { success: true }
        else
          @errors = source.errors.full_messages
          { success: false, errors: @errors }
        end
      end
    end
  end
end
