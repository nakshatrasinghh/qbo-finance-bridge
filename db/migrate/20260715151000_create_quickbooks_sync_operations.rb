class CreateQuickbooksSyncOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :quickbooks_sync_operations do |t|
      t.references :quickbooks_connection, null: false, foreign_key: true
      t.string :operation_type, null: false
      t.string :idempotency_key, null: false, limit: 50
      t.string :request_digest, null: false, limit: 64
      t.jsonb :request_payload, null: false
      t.string :status, null: false
      t.string :quickbooks_entity_type, null: false, default: "JournalEntry"
      t.string :quickbooks_entity_id
      t.jsonb :result_payload, null: false, default: {}
      t.string :error_code, limit: 64
      t.datetime :completed_at

      t.timestamps
    end

    add_index :quickbooks_sync_operations,
              %i[quickbooks_connection_id idempotency_key],
              unique: true,
              name: "index_qbo_sync_operations_on_connection_key"
    add_index :quickbooks_sync_operations,
              %i[quickbooks_connection_id created_at],
              name: "index_qbo_sync_operations_on_connection_created_at"
    add_index :quickbooks_sync_operations,
              %i[quickbooks_connection_id quickbooks_entity_type quickbooks_entity_id],
              where: "quickbooks_entity_id IS NOT NULL",
              name: "index_qbo_sync_operations_on_connection_entity"

    add_check_constraint :quickbooks_sync_operations,
                         "operation_type = 'journal_entry_create'",
                         name: "qbo_sync_operations_type_valid"
    add_check_constraint :quickbooks_sync_operations,
                         "status IN ('pending', 'succeeded', 'rejected', 'uncertain')",
                         name: "qbo_sync_operations_status_valid"
    add_check_constraint :quickbooks_sync_operations,
                         "idempotency_key ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'",
                         name: "qbo_sync_operations_key_uuid"
    add_check_constraint :quickbooks_sync_operations,
                         "request_digest ~ '^[0-9a-f]{64}$'",
                         name: "qbo_sync_operations_digest_sha256"
    add_check_constraint :quickbooks_sync_operations,
                         "jsonb_typeof(request_payload) = 'object' AND request_payload <> '{}'::jsonb",
                         name: "qbo_sync_operations_request_object"
    add_check_constraint :quickbooks_sync_operations,
                         "jsonb_typeof(result_payload) = 'object'",
                         name: "qbo_sync_operations_result_object"
    add_check_constraint :quickbooks_sync_operations,
                         "quickbooks_entity_type = 'JournalEntry'",
                         name: "qbo_sync_operations_entity_type_valid"
    add_check_constraint :quickbooks_sync_operations,
                         "quickbooks_entity_id IS NULL OR quickbooks_entity_id ~ '^[0-9]{1,255}$'",
                         name: "qbo_sync_operations_entity_id_valid"
    add_check_constraint :quickbooks_sync_operations,
                         "status = 'pending' OR completed_at IS NOT NULL",
                         name: "qbo_sync_operations_completion_present"
    add_check_constraint :quickbooks_sync_operations,
                         "status <> 'succeeded' OR (quickbooks_entity_id IS NOT NULL AND result_payload <> '{}'::jsonb)",
                         name: "qbo_sync_operations_success_result_present"
    add_check_constraint :quickbooks_sync_operations,
                         "(status IN ('rejected', 'uncertain') AND error_code IS NOT NULL) OR " \
                           "(status NOT IN ('rejected', 'uncertain') AND error_code IS NULL)",
                         name: "qbo_sync_operations_error_state_valid"
  end
end
