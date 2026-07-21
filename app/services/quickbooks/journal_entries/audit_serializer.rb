module Quickbooks
  module JournalEntries
    class AuditSerializer
      def self.call(operation)
        request = operation.request_payload

        {
          id: operation.id,
          status: operation.status,
          txn_date: request.fetch("txn_date"),
          memo: request.fetch("memo"),
          amount: request.fetch("amount"),
          debit_account_id: request.fetch("debit_account_id"),
          credit_account_id: request.fetch("credit_account_id"),
          quickbooks_journal_entry_id: operation.quickbooks_entity_id,
          error_code: operation.error_code,
          created_at: operation.created_at.iso8601(3),
          completed_at: operation.completed_at&.iso8601(3)
        }
      end
    end
  end
end
