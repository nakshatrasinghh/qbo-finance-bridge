module Quickbooks
  module Employees
    class Submit
      ATTRIBUTE_NAMES = %w[given_name family_name email phone].freeze
      Result = Data.define(:employee)

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
        employee = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(employee: Serializer.call(employee))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
