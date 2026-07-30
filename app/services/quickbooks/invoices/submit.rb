module Quickbooks
  module Invoices
    class Submit
      ATTRIBUTE_NAMES = %w[customer_id item_id txn_date due_date amount description].freeze
      Result = Data.define(:invoice)

      def self.canonical_attributes(attributes)
        values = attributes.to_h.stringify_keys
        ATTRIBUTE_NAMES.index_with { |name| values[name].to_s.strip }
      end

      def initialize(connection:, attributes:, client: nil)
        @connection = connection
        @attributes = self.class.canonical_attributes(attributes)
        @client = client
      end

      def call
        invoice = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(invoice: Serializer.invoice(invoice))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
