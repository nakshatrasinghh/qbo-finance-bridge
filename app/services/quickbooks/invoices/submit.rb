module Quickbooks
  module Invoices
    class Submit
      OPERATION_TYPE = "invoice_create"
      ATTRIBUTE_NAMES = %w[customer_id item_id txn_date due_date amount description].freeze
      Result = Data.define(:invoice, :operation, :replayed)

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
            entity_type: "Invoice",
            entity_label: "Invoice",
            attributes: attributes,
            creator: creator,
            serializer: Serializer.method(:invoice)
          ).call

        Result.new(invoice: result.payload, operation: result.operation, replayed: result.replayed)
      end

      private

      attr_reader :attributes, :client, :connection, :idempotency_key
    end
  end
end
