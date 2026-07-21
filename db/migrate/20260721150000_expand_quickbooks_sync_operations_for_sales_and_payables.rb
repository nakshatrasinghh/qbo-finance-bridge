class ExpandQuickbooksSyncOperationsForSalesAndPayables < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :quickbooks_sync_operations,
                            name: "qbo_sync_operations_operation_entity_valid"

    add_check_constraint :quickbooks_sync_operations,
                         operation_entity_constraint,
                         name: "qbo_sync_operations_operation_entity_valid"
  end

  private

  def operation_entity_constraint
    {
      "journal_entry_create" => "JournalEntry",
      "employee_create" => "Employee",
      "time_activity_create" => "TimeActivity",
      "tax_code_create" => "TaxCode",
      "inventory_item_create" => "Item",
      "customer_create" => "Customer",
      "vendor_create" => "Vendor",
      "invoice_create" => "Invoice",
      "bill_create" => "Bill",
      "customer_payment_create" => "Payment",
      "bill_payment_create" => "BillPayment"
    }.map do |operation_type, entity_type|
        "(operation_type = '#{operation_type}' AND quickbooks_entity_type = '#{entity_type}')"
      end
      .join(" OR ")
  end
end
