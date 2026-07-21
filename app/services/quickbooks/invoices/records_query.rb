module Quickbooks
  module Invoices
    class RecordsQuery
      MAX_RESULTS = 1_000

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection: connection)
      end

      def call
        response =
          client.get("query", params: { query: "SELECT * FROM Invoice MAXRESULTS #{MAX_RESULTS}" })
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["Invoice"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)

            invoice = Details.from_payload(payload)
            valid =
              invoice.id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT) &&
                valid_date?(invoice.txn_date) && valid_date?(invoice.due_date) &&
                invoice.customer_id.present? && invoice.total_amount && invoice.balance &&
                invoice.lines.all? { |line| valid_line?(line) }
            raise_unexpected! unless valid

            invoice
          end
          .sort_by { |invoice| [invoice.txn_date, invoice.id.to_i] }
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
        line.amount && line.item_id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT)
      end

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected Invoice data.",
                code: "quickbooks_invoices_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
