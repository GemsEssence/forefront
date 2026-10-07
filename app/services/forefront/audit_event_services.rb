module Forefront
  module AuditEventServices
    # Narrows the audit log by who did it, what kind of record, what they did
    # and when. `event_action` rather than `action`, which Rails already uses
    # for the controller action in params.
    class Filter
      attr_reader :scope, :filters

      def initialize(scope: AuditEvent.all, filters: {})
        @scope = scope
        @filters = filters
      end

      def call
        result = scope
        result = result.where(actor_id: filters[:actor_id]) if filters[:actor_id].present?
        result = result.where(auditable_type: filters[:auditable_type]) if filters[:auditable_type].present?
        result = result.where(auditable_id: filters[:auditable_id]) if filters[:auditable_id].present?
        result = result.where(action: filters[:event_action]) if filters[:event_action].present?
        result = result.where(created_at: date(filters[:from]).beginning_of_day..) if date(filters[:from])
        result = result.where(created_at: ..date(filters[:to]).end_of_day) if date(filters[:to])
        result
      end

      private

      def date(value)
        Date.parse(value.to_s) if value.present?
      rescue ArgumentError
        nil
      end
    end
  end
end
