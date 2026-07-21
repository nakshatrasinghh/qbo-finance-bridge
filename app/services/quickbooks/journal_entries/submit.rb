module Quickbooks
  module JournalEntries
    class Submit
      OPERATION_TYPE = "journal_entry_create"
      ATTRIBUTE_NAMES = %w[txn_date memo amount debit_account_id credit_account_id].freeze
      Result = Data.define(:journal_entry, :operation, :replayed)

      def self.canonical_attributes(attributes)
        values = attributes.to_h.stringify_keys
        ATTRIBUTE_NAMES.index_with { |name| values[name].to_s.strip }
      end

      def initialize(connection:, idempotency_key:, attributes:, client: nil)
        @connection = connection
        @idempotency_key = idempotency_key.to_s.downcase
        @attributes = self.class.canonical_attributes(attributes)
        @client = client
      end

      def call
        creator =
          Create.new(
            connection: connection,
            request_id: idempotency_key,
            client: client,
            **attributes.symbolize_keys
          )
        result =
          CreateSubmission.new(
            connection: connection,
            idempotency_key: idempotency_key,
            operation_type: OPERATION_TYPE,
            entity_type: "JournalEntry",
            entity_label: "Journal Entry",
            attributes: attributes,
            creator: creator,
            serializer: Serializer.method(:call)
          ).call

        Result.new(
          journal_entry: result.payload,
          operation: result.operation,
          replayed: result.replayed
        )
      end

      private

      attr_reader :attributes, :client, :connection, :idempotency_key
    end
  end
end
