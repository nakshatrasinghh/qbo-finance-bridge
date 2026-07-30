module Quickbooks
  module TimeActivities
    class Submit
      ATTRIBUTE_NAMES = %w[employee_id txn_date hours minutes description].freeze
      Result = Data.define(:time_activity)

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
        time_activity = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(time_activity: Serializer.call(time_activity))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
