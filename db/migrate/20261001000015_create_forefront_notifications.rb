# Alerts telling Staff something needs attention (CONTEXT.md). Each is
# shown in Forefront and emailed at most once; dedupe_key keeps a repeated
# check from raising the same alert twice.
class CreateForefrontNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :forefront_admins }
      t.string :kind, null: false
      t.references :subject, polymorphic: true, null: false
      t.text :message, null: false
      t.string :dedupe_key, null: false, default: ""
      t.datetime :read_at
      t.datetime :emailed_at
      t.timestamps
    end
    add_index :forefront_notifications, [ :recipient_id, :kind, :subject_type, :subject_id, :dedupe_key ],
              unique: true, name: "index_forefront_notifications_once"
  end
end
