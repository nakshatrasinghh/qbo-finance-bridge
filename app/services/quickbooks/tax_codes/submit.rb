module Quickbooks
  module TaxCodes
    class Submit
      ATTRIBUTE_NAMES = %w[name tax_rate_id applicable_on].freeze
      Result = Data.define(:tax_code)

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
        tax_code = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(tax_code: Serializer.code(tax_code))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
