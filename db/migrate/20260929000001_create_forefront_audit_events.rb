# One row per thing a Staff member did (see ADR 0006). auditable has no
# foreign key and auditable_label copies the record's name, so the event
# still reads correctly after the record itself is deleted.
class CreateForefrontAuditEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :forefront_audit_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :forefront_admins }
      t.string :action, null: false
      t.references :auditable, polymorphic: true, index: true
      t.string :auditable_label
      t.json :audited_changes, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :forefront_audit_events, :created_at
  end
end
