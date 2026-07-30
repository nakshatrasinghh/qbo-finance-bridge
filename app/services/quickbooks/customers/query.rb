module Quickbooks
  module Customers
    class Query
      MAX_RESULTS = 1_000

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection:)
      end

      def call
        response =
          client.get(
            "query",
            params: {
              query: "SELECT * FROM Customer WHERE Active = true MAXRESULTS #{MAX_RESULTS}"
            }
          )
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["Customer"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)

            customer = Details.from_payload(payload)
            valid =
              EntityId.valid?(customer.id) && customer.display_name.present? && customer.balance &&
                customer.active == true
            raise_unexpected! unless valid

            customer
          end
          .sort_by { |customer| customer.display_name.downcase }
          .freeze
      end

      private

      attr_reader :client

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected active Customer data.",
                code: "quickbooks_customers_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
