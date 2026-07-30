module Quickbooks
  module JournalEntries
    class Submit
      ATTRIBUTE_NAMES = %w[txn_date memo amount debit_account_id credit_account_id].freeze
      Result = Data.define(:journal_entry)

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
        journal_entry = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(journal_entry: Serializer.call(journal_entry))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
