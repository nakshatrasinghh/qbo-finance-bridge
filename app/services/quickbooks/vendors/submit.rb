module Quickbooks
  module Vendors
    class Submit
      OPERATION_TYPE = "vendor_create"
      ATTRIBUTE_NAMES = %w[display_name company_name email phone].freeze
      Result = Data.define(:vendor, :operation, :replayed)

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
            entity_type: "Vendor",
            entity_label: "Vendor",
            attributes: attributes,
            creator: creator,
            serializer: Serializer.method(:call)
          ).call

        Result.new(vendor: result.payload, operation: result.operation, replayed: result.replayed)
      end

      private

      attr_reader :attributes, :client, :connection, :idempotency_key
    end
  end
end
