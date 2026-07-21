module Quickbooks
  module Items
    class SalesChoices
      Choice = Data.define(:id, :name, :item_type)
      ELIGIBLE_TYPES = %w[Inventory NonInventory Service].freeze
      MAX_RESULTS = 1_000

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection: connection)
      end

      def call
        response =
          client.get(
            "query",
            params: {
              query: "SELECT * FROM Item WHERE Active = true MAXRESULTS #{MAX_RESULTS}"
            }
          )
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["Item"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .filter_map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)
            next unless ELIGIBLE_TYPES.include?(payload["Type"])

            choice =
              Choice.new(
                id: payload["Id"].to_s,
                name: payload["Name"].to_s,
                item_type: payload["Type"]
              )
            valid =
              choice.id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT) && choice.name.present?
            raise_unexpected! unless valid

            choice
          end
          .sort_by { |choice| choice.name.downcase }
          .freeze
      end

      private

      attr_reader :client

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected sales Item data.",
                code: "quickbooks_sales_items_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
