# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_01_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "forefront_activities", force: :cascade do |t|
    t.bigint "actable_id", null: false
    t.string "actable_type", null: false
    t.string "activity_type", default: "comment", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actable_type", "actable_id"], name: "index_forefront_activities_on_actable"
    t.index ["activity_type"], name: "index_forefront_activities_on_activity_type"
    t.index ["created_at"], name: "index_forefront_activities_on_created_at"
    t.index ["created_by_id"], name: "index_forefront_activities_on_created_by_id"
  end

  create_table "forefront_admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.bigint "manager_id"
    t.string "name", null: false
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.string "role", default: "sales_person", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_forefront_admins_on_email", unique: true
    t.index ["manager_id"], name: "index_forefront_admins_on_manager_id"
    t.index ["reset_password_token"], name: "index_forefront_admins_on_reset_password_token", unique: true
    t.index ["role"], name: "index_forefront_admins_on_role"
  end

  create_table "forefront_assignments", force: :cascade do |t|
    t.bigint "assignable_id", null: false
    t.string "assignable_type", null: false
    t.bigint "changed_by_id", null: false
    t.datetime "created_at", null: false
    t.bigint "from_user_id"
    t.text "note"
    t.bigint "to_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["assignable_type", "assignable_id"], name: "index_forefront_assignments_on_assignable"
    t.index ["changed_by_id"], name: "index_forefront_assignments_on_changed_by_id"
    t.index ["from_user_id"], name: "index_forefront_assignments_on_from_user_id"
    t.index ["to_user_id"], name: "index_forefront_assignments_on_to_user_id"
  end

  create_table "forefront_audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id", null: false
    t.bigint "auditable_id"
    t.string "auditable_label"
    t.string "auditable_type"
    t.json "audited_changes", default: {}, null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["actor_id"], name: "index_forefront_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_forefront_audit_events_on_auditable"
    t.index ["created_at"], name: "index_forefront_audit_events_on_created_at"
  end

  create_table "forefront_customers", force: :cascade do |t|
    t.text "address"
    t.string "business_name"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "external_id"
    t.string "external_type"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_forefront_customers_on_email", unique: true
    t.index ["external_type", "external_id"], name: "index_forefront_customers_on_external_reference", unique: true
    t.index ["phone"], name: "index_forefront_customers_on_phone"
  end

  create_table "forefront_followups", force: :cascade do |t|
    t.bigint "assigned_to_id", null: false
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "followup_type", default: "call", null: false
    t.bigint "followupable_id", null: false
    t.string "followupable_type", null: false
    t.text "outcome"
    t.datetime "scheduled_for", precision: nil
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_forefront_followups_on_assigned_to_id"
    t.index ["created_by_id"], name: "index_forefront_followups_on_created_by_id"
    t.index ["followupable_type", "followupable_id"], name: "index_forefront_followups_on_followupable"
  end

  create_table "forefront_installments", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.datetime "paid_at", precision: nil
    t.bigint "payment_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "index_forefront_installments_on_payment_id"
  end

  create_table "forefront_lead_share_participants", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.datetime "created_at", null: false
    t.bigint "lead_share_id", null: false
    t.decimal "percentage", precision: 5, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_forefront_lead_share_participants_on_admin_id"
    t.index ["lead_share_id", "admin_id"], name: "index_forefront_lsp_on_lead_share_and_admin", unique: true
    t.index ["lead_share_id"], name: "index_forefront_lead_share_participants_on_lead_share_id"
  end

  create_table "forefront_lead_shares", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "lead_id", null: false
    t.bigint "recorded_by_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_forefront_lead_shares_on_lead_id", unique: true
    t.index ["recorded_by_id"], name: "index_forefront_lead_shares_on_recorded_by_id"
  end

  create_table "forefront_leads", force: :cascade do |t|
    t.decimal "actual_amount", precision: 12, scale: 2
    t.date "agreement_signed_on"
    t.bigint "assigned_to_id"
    t.datetime "awaiting_customer_since", precision: nil
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_id", null: false
    t.text "description"
    t.date "due_at"
    t.decimal "estimated_amount", precision: 12, scale: 2
    t.date "expires_at"
    t.text "lost_note"
    t.bigint "lost_reason_id"
    t.datetime "next_followup_at", precision: nil
    t.bigint "product_id"
    t.bigint "source_id", null: false
    t.string "status", default: "Open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.boolean "white_label", default: false, null: false
    t.datetime "won_at", precision: nil
    t.index ["assigned_to_id"], name: "index_forefront_leads_on_assigned_to_id"
    t.index ["created_by_id"], name: "index_forefront_leads_on_created_by_id"
    t.index ["customer_id"], name: "index_forefront_leads_on_customer_id"
    t.index ["due_at"], name: "index_forefront_leads_on_due_at"
    t.index ["lost_reason_id"], name: "index_forefront_leads_on_lost_reason_id"
    t.index ["next_followup_at"], name: "index_forefront_leads_on_next_followup_at"
    t.index ["product_id"], name: "index_forefront_leads_on_product_id"
    t.index ["source_id"], name: "index_forefront_leads_on_source_id"
    t.index ["status"], name: "index_forefront_leads_on_status"
  end

  create_table "forefront_lost_reasons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_forefront_lost_reasons_on_name", unique: true
  end

  create_table "forefront_payments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "lead_id", null: false
    t.datetime "paid_at", precision: nil
    t.string "status", default: "pending", null: false
    t.decimal "total_amount", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_forefront_payments_on_lead_id", unique: true
  end

  create_table "forefront_product_allocations", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_forefront_product_allocations_on_admin_id"
    t.index ["product_id", "admin_id"], name: "index_forefront_product_allocations_on_product_id_and_admin_id", unique: true
    t.index ["product_id"], name: "index_forefront_product_allocations_on_product_id"
  end

  create_table "forefront_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.decimal "reclaim_reward_percentage", precision: 5, scale: 2
    t.decimal "renewal_reward_percentage", precision: 5, scale: 2
    t.datetime "updated_at", null: false
  end

  create_table "forefront_sources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_forefront_sources_on_name", unique: true
  end

  create_table "forefront_status_histories", force: :cascade do |t|
    t.bigint "changed_by_id", null: false
    t.datetime "created_at", null: false
    t.string "new_status", null: false
    t.text "note"
    t.string "old_status"
    t.bigint "trackable_id", null: false
    t.string "trackable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_forefront_status_histories_on_changed_by_id"
    t.index ["trackable_type", "trackable_id"], name: "index_forefront_status_histories_on_trackable"
  end

  create_table "forefront_subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.date "expires_at", null: false
    t.bigint "lead_id", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_forefront_subscriptions_on_customer_id"
    t.index ["lead_id"], name: "index_forefront_subscriptions_on_lead_id", unique: true
    t.index ["product_id"], name: "index_forefront_subscriptions_on_product_id"
  end

  create_table "forefront_targets", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.string "bonus_type"
    t.decimal "bonus_value", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.decimal "goal_value", precision: 12, scale: 2, null: false
    t.string "metric", null: false
    t.string "period", null: false
    t.bigint "product_id", null: false
    t.string "reward_type"
    t.decimal "reward_value", precision: 12, scale: 2
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id", "product_id", "starts_on", "period"], name: "index_forefront_targets_on_admin_product_period", unique: true
    t.index ["admin_id"], name: "index_forefront_targets_on_admin_id"
    t.index ["product_id"], name: "index_forefront_targets_on_product_id"
  end

  create_table "forefront_tickets", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.string "category", default: "issue", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_id", null: false
    t.text "description"
    t.date "due_at"
    t.datetime "next_followup_at", precision: nil
    t.string "priority", default: "medium", null: false
    t.bigint "product_id"
    t.string "renewal_outcome"
    t.string "status", default: "Open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_forefront_tickets_on_assigned_to_id"
    t.index ["category"], name: "index_forefront_tickets_on_category"
    t.index ["created_by_id"], name: "index_forefront_tickets_on_created_by_id"
    t.index ["customer_id"], name: "index_forefront_tickets_on_customer_id"
    t.index ["due_at"], name: "index_forefront_tickets_on_due_at"
    t.index ["next_followup_at"], name: "index_forefront_tickets_on_next_followup_at"
    t.index ["priority"], name: "index_forefront_tickets_on_priority"
    t.index ["product_id"], name: "index_forefront_tickets_on_product_id"
    t.index ["status"], name: "index_forefront_tickets_on_status"
  end

  add_foreign_key "forefront_activities", "forefront_admins", column: "created_by_id"
  add_foreign_key "forefront_admins", "forefront_admins", column: "manager_id"
  add_foreign_key "forefront_assignments", "forefront_admins", column: "changed_by_id"
  add_foreign_key "forefront_assignments", "forefront_admins", column: "from_user_id"
  add_foreign_key "forefront_assignments", "forefront_admins", column: "to_user_id"
  add_foreign_key "forefront_audit_events", "forefront_admins", column: "actor_id"
  add_foreign_key "forefront_followups", "forefront_admins", column: "assigned_to_id"
  add_foreign_key "forefront_followups", "forefront_admins", column: "created_by_id"
  add_foreign_key "forefront_installments", "forefront_payments", column: "payment_id"
  add_foreign_key "forefront_lead_share_participants", "forefront_admins", column: "admin_id"
  add_foreign_key "forefront_lead_share_participants", "forefront_lead_shares", column: "lead_share_id"
  add_foreign_key "forefront_lead_shares", "forefront_admins", column: "recorded_by_id"
  add_foreign_key "forefront_lead_shares", "forefront_leads", column: "lead_id"
  add_foreign_key "forefront_leads", "forefront_admins", column: "assigned_to_id"
  add_foreign_key "forefront_leads", "forefront_admins", column: "created_by_id"
  add_foreign_key "forefront_leads", "forefront_customers", column: "customer_id"
  add_foreign_key "forefront_leads", "forefront_lost_reasons", column: "lost_reason_id"
  add_foreign_key "forefront_leads", "forefront_products", column: "product_id"
  add_foreign_key "forefront_leads", "forefront_sources", column: "source_id"
  add_foreign_key "forefront_payments", "forefront_leads", column: "lead_id"
  add_foreign_key "forefront_product_allocations", "forefront_admins", column: "admin_id"
  add_foreign_key "forefront_product_allocations", "forefront_products", column: "product_id"
  add_foreign_key "forefront_status_histories", "forefront_admins", column: "changed_by_id"
  add_foreign_key "forefront_subscriptions", "forefront_customers", column: "customer_id"
  add_foreign_key "forefront_subscriptions", "forefront_leads", column: "lead_id"
  add_foreign_key "forefront_subscriptions", "forefront_products", column: "product_id"
  add_foreign_key "forefront_targets", "forefront_admins", column: "admin_id"
  add_foreign_key "forefront_targets", "forefront_products", column: "product_id"
  add_foreign_key "forefront_tickets", "forefront_admins", column: "assigned_to_id"
  add_foreign_key "forefront_tickets", "forefront_admins", column: "created_by_id"
  add_foreign_key "forefront_tickets", "forefront_customers", column: "customer_id"
  add_foreign_key "forefront_tickets", "forefront_products", column: "product_id"
end
