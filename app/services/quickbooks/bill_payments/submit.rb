module Quickbooks
  module BillPayments
    class Submit
      ATTRIBUTE_NAMES = %w[bill_id bank_account_id txn_date amount].freeze
      Result = Data.define(:bill_payment)

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
        bill_payment = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(bill_payment: Serializer.payment(bill_payment))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
