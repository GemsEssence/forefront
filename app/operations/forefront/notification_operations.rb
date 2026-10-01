module Forefront
  module NotificationOperations
    # Raises one kind of alert about one record for each recipient, at most
    # once per dedupe key, so running the same check again changes nothing.
    class Notify
      def initialize(kind:, subject:, recipients:, message:, key: "")
        @kind = kind
        @subject = subject
        @recipients = recipients
        @message = message
        @key = key.to_s
      end

      def call
        @recipients.reject(&:system?).map do |recipient|
          Notification.create_or_find_by!(recipient: recipient, kind: @kind, subject: @subject, dedupe_key: @key) do |notification|
            notification.message = @message
          end
        end
      end
    end

    # New work nobody's been given: tell the Managers and Admins who hand it
    # out, apart from whoever left it unassigned.
    class AnnounceUnassigned
      def initialize(record:, created_by:)
        @record = record
        @created_by = created_by
      end

      def call
        return if @record.assigned_to_id.present?

        recipients = Admin.people.where(role: %w[admin manager]).where.not(id: @created_by.id)
        kind_name = @record.class.model_name.human.downcase
        Notify.new(kind: "unassigned", subject: @record, recipients: recipients, message: "New unassigned #{kind_name}: #{@record.title}").call
      end
    end

    class MarkRead
      def initialize(notifications:)
        @notifications = notifications
      end

      def call
        @notifications.unread.update_all(read_at: Time.current)
      end
    end
  end
end
