module Quickbooks
  module BillPayments
    class RecordsQuery
      MAX_RESULTS = 1_000
      PAY_TYPES = %w[Check CreditCard].freeze

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection:)
      end

      def call
        response =
          client.get(
            "query",
            params: {
              query: "SELECT * FROM BillPayment MAXRESULTS #{MAX_RESULTS}"
            }
          )
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["BillPayment"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)

            payment = Details.from_payload(payload)
            valid =
              EntityId.valid?(payment.id) && valid_date?(payment.txn_date) &&
                payment.vendor_id.present? && PAY_TYPES.include?(payment.pay_type) &&
                payment.payment_account_id.present? && payment.total_amount &&
                payment.applied_bills.all? { |bill| valid_applied_bill?(bill) }
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

      def valid_applied_bill?(bill)
        EntityId.valid?(bill.bill_id) && bill.amount
      end

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected BillPayment data.",
                code: "quickbooks_bill_payments_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
