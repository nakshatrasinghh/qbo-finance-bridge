class ExpandQuickbooksSyncOperationTypes < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :quickbooks_sync_operations, name: "qbo_sync_operations_type_valid"
    remove_check_constraint :quickbooks_sync_operations,
                            name: "qbo_sync_operations_entity_type_valid"
    remove_check_constraint :quickbooks_sync_operations, name: "qbo_sync_operations_entity_id_valid"

    add_check_constraint :quickbooks_sync_operations,
                         "(operation_type = 'journal_entry_create' AND quickbooks_entity_type = 'JournalEntry') OR " \
                           "(operation_type = 'employee_create' AND quickbooks_entity_type = 'Employee') OR " \
                           "(operation_type = 'time_activity_create' AND quickbooks_entity_type = 'TimeActivity') OR " \
                           "(operation_type = 'tax_code_create' AND quickbooks_entity_type = 'TaxCode') OR " \
                           "(operation_type = 'inventory_item_create' AND quickbooks_entity_type = 'Item')",
                         name: "qbo_sync_operations_operation_entity_valid"
    add_check_constraint :quickbooks_sync_operations,
                         "quickbooks_entity_id IS NULL OR " \
                           "quickbooks_entity_id ~ '^[A-Za-z0-9_.:-]{1,255}$'",
                         name: "qbo_sync_operations_entity_id_valid"
  end
end
