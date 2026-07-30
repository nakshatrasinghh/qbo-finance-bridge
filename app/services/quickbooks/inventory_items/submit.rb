module Quickbooks
  module InventoryItems
    class Submit
      ATTRIBUTE_NAMES = %w[
        name
        sku
        description
        inventory_start_date
        quantity_on_hand
        unit_price
        purchase_cost
        income_account_id
        expense_account_id
        asset_account_id
      ].freeze
      Result = Data.define(:inventory_item)

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
        inventory_item = Create.new(connection:, client:, **attributes.symbolize_keys).call

        Result.new(inventory_item: Serializer.item(inventory_item))
      end

      private

      attr_reader :attributes, :client, :connection
    end
  end
end
