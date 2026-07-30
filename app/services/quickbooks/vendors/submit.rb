module Quickbooks
  module Vendors
    class Submit
      ATTRIBUTE_NAMES = %w[display_name company_name email phone].freeze
      Result = Data.define(:vendor)

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
        vendor = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(vendor: Serializer.call(vendor))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
