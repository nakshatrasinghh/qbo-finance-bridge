module Quickbooks
  module CustomerPayments
    class RecordsQuery
      MAX_RESULTS = 1_000

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection: connection)
      end

      def call
        response =
          client.get("query", params: { query: "SELECT * FROM Payment MAXRESULTS #{MAX_RESULTS}" })
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["Payment"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)

            payment = Details.from_payload(payload)
            valid =
              payment.id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT) &&
                valid_date?(payment.txn_date) && payment.customer_id.present? &&
                payment.total_amount && payment.unapplied_amount &&
                payment.applied_invoices.all? { |invoice| valid_applied_invoice?(invoice) }
            raise_unexpected! unless valid

            payment
          end
          .sort_by { |payment| [payment.txn_date, payment.id.to_i] }
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

      def valid_applied_invoice?(invoice)
        invoice.invoice_id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT) && invoice.amount
      end

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected customer Payment data.",
                code: "quickbooks_customer_payments_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
