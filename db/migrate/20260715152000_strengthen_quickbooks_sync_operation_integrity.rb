class StrengthenQuickbooksSyncOperationIntegrity < ActiveRecord::Migration[8.1]
  def change
    remove_index :quickbooks_sync_operations, name: "index_qbo_sync_operations_on_connection_entity"
    add_index :quickbooks_sync_operations,
              %i[quickbooks_connection_id quickbooks_entity_type quickbooks_entity_id],
              unique: true,
              where: "quickbooks_entity_id IS NOT NULL",
              name: "index_qbo_sync_operations_on_connection_entity"

    remove_check_constraint :quickbooks_sync_operations, name: "qbo_sync_operations_key_uuid"
    add_check_constraint :quickbooks_sync_operations,
                         "idempotency_key ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'",
                         name: "qbo_sync_operations_key_uuid"

    remove_check_constraint :quickbooks_sync_operations,
                            name: "qbo_sync_operations_completion_present"
    add_check_constraint :quickbooks_sync_operations,
                         "(status = 'pending' AND completed_at IS NULL) OR " \
                           "(status <> 'pending' AND completed_at IS NOT NULL)",
                         name: "qbo_sync_operations_completion_state_valid"
    add_check_constraint :quickbooks_sync_operations,
                         "status = 'succeeded' OR result_payload = '{}'::jsonb",
                         name: "qbo_sync_operations_nonsuccess_result_empty"
    add_check_constraint :quickbooks_sync_operations,
                         "status NOT IN ('pending', 'rejected') OR quickbooks_entity_id IS NULL",
                         name: "qbo_sync_operations_unresolved_entity_absent"
  end
end
