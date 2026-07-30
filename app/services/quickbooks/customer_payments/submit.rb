module Quickbooks
  module CustomerPayments
    class Submit
      ATTRIBUTE_NAMES = %w[invoice_id txn_date amount].freeze
      Result = Data.define(:customer_payment)

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
        customer_payment = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(customer_payment: Serializer.payment(customer_payment))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
