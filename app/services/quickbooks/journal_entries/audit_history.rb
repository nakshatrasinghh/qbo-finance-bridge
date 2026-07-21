module Quickbooks
  module JournalEntries
    class AuditHistory
      SELECTED_COLUMNS = %i[
        id
        status
        request_payload
        quickbooks_entity_id
        error_code
        created_at
        completed_at
      ].freeze

      def initialize(connection:, parameters:)
        @connection = connection
        @parameters = parameters
      end

      def call
        records = filtered_relation.limit(parameters.query_limit).to_a
        has_more = records.length > parameters.per_page

        ReadPage.new(
          records: records.first(parameters.per_page).freeze,
          parameters: parameters,
          has_more: has_more
        )
      end

      private

      attr_reader :connection, :parameters

      def filtered_relation
        relation =
          connection
            .quickbooks_sync_operations
            .where(operation_type: "journal_entry_create")
            .select(*SELECTED_COLUMNS)
            .order(created_at: :desc, id: :desc)
            .offset(parameters.offset)
            .readonly

        if parameters.txn_date_from
          relation =
            relation.where("request_payload->>'txn_date' >= ?", parameters.txn_date_from.iso8601)
        end
        if parameters.txn_date_to
          relation =
            relation.where("request_payload->>'txn_date' <= ?", parameters.txn_date_to.iso8601)
        end

        relation
      end
    end
  end
end
