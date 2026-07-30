module Quickbooks
  module Vendors
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
              query: "SELECT * FROM Vendor WHERE Active = true MAXRESULTS #{MAX_RESULTS}"
            }
          )
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["Vendor"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)

            vendor = Details.from_payload(payload)
            valid =
              EntityId.valid?(vendor.id) && vendor.display_name.present? && vendor.balance &&
                vendor.active == true
            raise_unexpected! unless valid

            vendor
          end
          .sort_by { |vendor| vendor.display_name.downcase }
          .freeze
      end

      private

      attr_reader :client

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected active Vendor data.",
                code: "quickbooks_vendors_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
