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

ActiveRecord::Schema[8.1].define(version: 2026_07_21_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_verified_at", null: false
    t.string "quickbooks_account_id", null: false
    t.string "quickbooks_account_name", null: false
    t.string "quickbooks_account_subtype"
    t.string "quickbooks_account_type", null: false
    t.bigint "quickbooks_connection_id", null: false
    t.string "source_account_code", null: false
    t.string "source_account_name", null: false
    t.string "source_system", null: false
    t.datetime "updated_at", null: false
    t.index ["quickbooks_connection_id", "quickbooks_account_id"], name: "index_account_mappings_on_connection_qbo_account"
    t.index ["quickbooks_connection_id", "source_system", "source_account_code"], name: "index_account_mappings_on_connection_source", unique: true
    t.index ["quickbooks_connection_id"], name: "index_account_mappings_on_quickbooks_connection_id"
    t.check_constraint "char_length(btrim(quickbooks_account_id::text)) >= 1 AND char_length(btrim(quickbooks_account_id::text)) <= 255", name: "account_mappings_qbo_id_length"
    t.check_constraint "char_length(btrim(quickbooks_account_name::text)) >= 1 AND char_length(btrim(quickbooks_account_name::text)) <= 255", name: "account_mappings_qbo_name_length"
    t.check_constraint "char_length(btrim(quickbooks_account_type::text)) >= 1 AND char_length(btrim(quickbooks_account_type::text)) <= 100", name: "account_mappings_qbo_type_length"
    t.check_constraint "char_length(btrim(source_account_code::text)) >= 1 AND char_length(btrim(source_account_code::text)) <= 100", name: "account_mappings_source_code_length"
    t.check_constraint "char_length(btrim(source_account_name::text)) >= 1 AND char_length(btrim(source_account_name::text)) <= 255", name: "account_mappings_source_name_length"
    t.check_constraint "char_length(btrim(source_system::text)) >= 1 AND char_length(btrim(source_system::text)) <= 100", name: "account_mappings_source_system_length"
    t.check_constraint "quickbooks_account_subtype IS NULL OR char_length(btrim(quickbooks_account_subtype::text)) >= 1 AND char_length(btrim(quickbooks_account_subtype::text)) <= 100", name: "account_mappings_qbo_subtype_length"
  end

  create_table "quickbooks_connections", force: :cascade do |t|
    t.text "access_token"
    t.datetime "access_token_expires_at"
    t.datetime "created_at", null: false
    t.datetime "disconnected_at"
    t.string "environment", null: false
    t.string "granted_scopes", default: "com.intuit.quickbooks.accounting", null: false
    t.datetime "last_refreshed_at"
    t.integer "lock_version", default: 0, null: false
    t.string "realm_id", null: false
    t.text "refresh_token"
    t.datetime "refresh_token_expires_at"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["environment", "realm_id"], name: "index_quickbooks_connections_on_environment_and_realm_id", unique: true
    t.index ["status"], name: "index_quickbooks_connections_on_status"
    t.check_constraint "char_length(realm_id::text) <= 255", name: "quickbooks_connections_realm_id_length"
    t.check_constraint "environment::text = ANY (ARRAY['sandbox'::character varying, 'production'::character varying]::text[])", name: "quickbooks_connections_environment_valid"
    t.check_constraint "realm_id::text ~ '^[0-9]+$'::text", name: "quickbooks_connections_realm_id_numeric"
    t.check_constraint "status::text <> 'active'::text OR access_token IS NOT NULL AND refresh_token IS NOT NULL AND access_token_expires_at IS NOT NULL", name: "quickbooks_connections_active_tokens_present"
    t.check_constraint "status::text <> 'disconnected'::text OR access_token IS NULL AND refresh_token IS NULL AND access_token_expires_at IS NULL", name: "quickbooks_connections_disconnected_tokens_cleared"
    t.check_constraint "status::text <> 'disconnected'::text OR disconnected_at IS NOT NULL", name: "quickbooks_connections_disconnect_time_present"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'disconnected'::character varying]::text[])", name: "quickbooks_connections_status_valid"
  end

  create_table "quickbooks_sync_operations", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "error_code", limit: 64
    t.string "idempotency_key", limit: 50, null: false
    t.string "operation_type", null: false
    t.bigint "quickbooks_connection_id", null: false
    t.string "quickbooks_entity_id"
    t.string "quickbooks_entity_type", default: "JournalEntry", null: false
    t.string "request_digest", limit: 64, null: false
    t.jsonb "request_payload", null: false
    t.jsonb "result_payload", default: {}, null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["quickbooks_connection_id", "created_at"], name: "index_qbo_sync_operations_on_connection_created_at"
    t.index ["quickbooks_connection_id", "idempotency_key"], name: "index_qbo_sync_operations_on_connection_key", unique: true
    t.index ["quickbooks_connection_id", "quickbooks_entity_type", "quickbooks_entity_id"], name: "index_qbo_sync_operations_on_connection_entity", unique: true, where: "(quickbooks_entity_id IS NOT NULL)"
    t.index ["quickbooks_connection_id"], name: "index_quickbooks_sync_operations_on_quickbooks_connection_id"
    t.check_constraint "(status::text <> ALL (ARRAY['pending'::character varying, 'rejected'::character varying]::text[])) OR quickbooks_entity_id IS NULL", name: "qbo_sync_operations_unresolved_entity_absent"
    t.check_constraint "(status::text = ANY (ARRAY['rejected'::character varying, 'uncertain'::character varying]::text[])) AND error_code IS NOT NULL OR (status::text <> ALL (ARRAY['rejected'::character varying, 'uncertain'::character varying]::text[])) AND error_code IS NULL", name: "qbo_sync_operations_error_state_valid"
    t.check_constraint "idempotency_key::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'::text", name: "qbo_sync_operations_key_uuid"
    t.check_constraint "jsonb_typeof(request_payload) = 'object'::text AND request_payload <> '{}'::jsonb", name: "qbo_sync_operations_request_object"
    t.check_constraint "jsonb_typeof(result_payload) = 'object'::text", name: "qbo_sync_operations_result_object"
    t.check_constraint "operation_type::text = 'journal_entry_create'::text AND quickbooks_entity_type::text = 'JournalEntry'::text OR operation_type::text = 'employee_create'::text AND quickbooks_entity_type::text = 'Employee'::text OR operation_type::text = 'time_activity_create'::text AND quickbooks_entity_type::text = 'TimeActivity'::text OR operation_type::text = 'tax_code_create'::text AND quickbooks_entity_type::text = 'TaxCode'::text OR operation_type::text = 'inventory_item_create'::text AND quickbooks_entity_type::text = 'Item'::text OR operation_type::text = 'customer_create'::text AND quickbooks_entity_type::text = 'Customer'::text OR operation_type::text = 'vendor_create'::text AND quickbooks_entity_type::text = 'Vendor'::text OR operation_type::text = 'invoice_create'::text AND quickbooks_entity_type::text = 'Invoice'::text OR operation_type::text = 'bill_create'::text AND quickbooks_entity_type::text = 'Bill'::text OR operation_type::text = 'customer_payment_create'::text AND quickbooks_entity_type::text = 'Payment'::text OR operation_type::text = 'bill_payment_create'::text AND quickbooks_entity_type::text = 'BillPayment'::text", name: "qbo_sync_operations_operation_entity_valid"
    t.check_constraint "quickbooks_entity_id IS NULL OR quickbooks_entity_id::text ~ '^[A-Za-z0-9_.:-]{1,255}$'::text", name: "qbo_sync_operations_entity_id_valid"
    t.check_constraint "request_digest::text ~ '^[0-9a-f]{64}$'::text", name: "qbo_sync_operations_digest_sha256"
    t.check_constraint "status::text <> 'succeeded'::text OR quickbooks_entity_id IS NOT NULL AND result_payload <> '{}'::jsonb", name: "qbo_sync_operations_success_result_present"
    t.check_constraint "status::text = 'pending'::text AND completed_at IS NULL OR status::text <> 'pending'::text AND completed_at IS NOT NULL", name: "qbo_sync_operations_completion_state_valid"
    t.check_constraint "status::text = 'succeeded'::text OR result_payload = '{}'::jsonb", name: "qbo_sync_operations_nonsuccess_result_empty"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'succeeded'::character varying, 'rejected'::character varying, 'uncertain'::character varying]::text[])", name: "qbo_sync_operations_status_valid"
  end

  add_foreign_key "account_mappings", "quickbooks_connections"
  add_foreign_key "quickbooks_sync_operations", "quickbooks_connections"
end
