module Quickbooks
  module Bills
    class Submit
      ATTRIBUTE_NAMES = %w[
        vendor_id
        expense_account_id
        payable_account_id
        txn_date
        due_date
        amount
        description
      ].freeze
      Result = Data.define(:bill)

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
        bill = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(bill: Serializer.bill(bill))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
