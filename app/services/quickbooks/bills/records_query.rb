module Quickbooks
  module Bills
    class RecordsQuery
      MAX_RESULTS = 1_000

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection:)
      end

      def call
        response =
          client.get("query", params: { query: "SELECT * FROM Bill MAXRESULTS #{MAX_RESULTS}" })
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["Bill"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)

            bill = Details.from_payload(payload)
            valid =
              EntityId.valid?(bill.id) && valid_date?(bill.txn_date) &&
                valid_date?(bill.due_date) && bill.vendor_id.present? &&
                bill.payable_account_id.present? && bill.total_amount && bill.balance &&
                bill.lines.all? { |line| valid_line?(line) }
            raise_unexpected! unless valid

            bill
          end
          .sort_by { |bill| [bill.txn_date, bill.id.to_i] }
          .reverse
          .freeze
      end

      private

      attr_reader :client

      def valid_date?(value)
        Date.iso8601(value).iso8601 == value
      rescue Date::Error
        false
      end

      def valid_line?(line)
        line.amount && EntityId.valid?(line.account_id)
      end

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected Bill data.",
                code: "quickbooks_bills_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
