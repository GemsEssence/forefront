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

ActiveRecord::Schema[8.1].define(version: 2025_12_07_000003) do
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
    t.string "name", null: false
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.boolean "super_admin", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_forefront_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_forefront_admins_on_reset_password_token", unique: true
    t.index ["super_admin"], name: "index_forefront_admins_on_super_admin"
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

  create_table "forefront_customers", force: :cascade do |t|
    t.text "address"
    t.string "business_name"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_forefront_customers_on_email", unique: true
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

  create_table "forefront_leads", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_id", null: false
    t.text "description"
    t.date "due_at"
    t.datetime "next_followup_at", precision: nil
    t.string "source", default: "website", null: false
    t.string "status", default: "Open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_forefront_leads_on_assigned_to_id"
    t.index ["created_by_id"], name: "index_forefront_leads_on_created_by_id"
    t.index ["customer_id"], name: "index_forefront_leads_on_customer_id"
    t.index ["due_at"], name: "index_forefront_leads_on_due_at"
    t.index ["next_followup_at"], name: "index_forefront_leads_on_next_followup_at"
    t.index ["source"], name: "index_forefront_leads_on_source"
    t.index ["status"], name: "index_forefront_leads_on_status"
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
    t.index ["status"], name: "index_forefront_tickets_on_status"
  end

  add_foreign_key "forefront_activities", "forefront_admins", column: "created_by_id"
  add_foreign_key "forefront_assignments", "forefront_admins", column: "changed_by_id"
  add_foreign_key "forefront_assignments", "forefront_admins", column: "from_user_id"
  add_foreign_key "forefront_assignments", "forefront_admins", column: "to_user_id"
  add_foreign_key "forefront_followups", "forefront_admins", column: "assigned_to_id"
  add_foreign_key "forefront_followups", "forefront_admins", column: "created_by_id"
  add_foreign_key "forefront_leads", "forefront_admins", column: "assigned_to_id"
  add_foreign_key "forefront_leads", "forefront_admins", column: "created_by_id"
  add_foreign_key "forefront_leads", "forefront_customers", column: "customer_id"
  add_foreign_key "forefront_status_histories", "forefront_admins", column: "changed_by_id"
  add_foreign_key "forefront_tickets", "forefront_admins", column: "assigned_to_id"
  add_foreign_key "forefront_tickets", "forefront_admins", column: "created_by_id"
  add_foreign_key "forefront_tickets", "forefront_customers", column: "customer_id"
end
