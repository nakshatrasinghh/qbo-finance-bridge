module Quickbooks
  module CustomerPayments
    class Create
      MONEY_PATTERN = /\A\d{1,11}(?:\.\d{1,2})?\z/

      def initialize(connection:, invoice_id: nil, txn_date: nil, amount: nil, client: nil)
        @connection = connection
        @invoice_id = invoice_id.to_s
        @txn_date_input = txn_date.to_s
        @amount_input = amount.to_s.strip
        @client = client || Client.new(connection:)
      end

      def call
        validate_input!
        load_open_invoice!

        response = client.post("payment", json: payload)
        quickbooks_entity_id = response.dig("Payment", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created Payment ID.")
        end

        readback(quickbooks_entity_id)
      end

      private

      attr_reader :amount, :client, :connection, :invoice, :invoice_id, :txn_date

      def validate_input!
        raise_input!("Choose a valid open QuickBooks Invoice.") unless EntityId.valid?(invoice_id)

        @txn_date = Date.iso8601(@txn_date_input)
        unless txn_date.iso8601 == @txn_date_input
          raise_input!("Payment date must be an ISO 8601 date.")
        end
        unless @amount_input.match?(MONEY_PATTERN)
          raise_input!("Payment amount must be a positive decimal with at most two places.")
        end

        @amount = BigDecimal(@amount_input)
        raise_input!("Payment amount must be greater than zero.") unless amount.positive?
      rescue Date::Error
        raise_input!("Payment date must be an ISO 8601 date.")
      end

      def load_open_invoice!
        @invoice =
          Invoices::RecordsQuery
            .new(connection:, client:)
            .call
            .find { |candidate| candidate.id == invoice_id }
        raise_input!("The selected Invoice is not available in QuickBooks.") unless invoice
        unless invoice.balance.positive?
          raise_input!("The selected Invoice has no outstanding balance.")
        end
        if amount > invoice.balance
          raise_input!("Payment amount cannot exceed the Invoice balance.")
        end
      end

      def payload
        {
          "TxnDate" => txn_date.iso8601,
          "CustomerRef" => {
            "value" => invoice.customer_id
          },
          "TotalAmt" => JSON::Fragment.new(amount.to_s("F")),
          "Line" => [
            {
              "Amount" => JSON::Fragment.new(amount.to_s("F")),
              "LinkedTxn" => [{ "TxnId" => invoice.id, "TxnType" => "Invoice" }]
            }
          ]
        }
      end

      def readback(id)
        response = client.get("payment/#{id}")
        raw = response["Payment"]
        unless raw.is_a?(Hash)
          raise_unexpected!("QuickBooks returned invalid Payment readback data.")
        end

        payment = Details.from_payload(raw)
        linked =
          payment.applied_invoices.find do |applied|
            applied.invoice_id == invoice.id && applied.amount == amount
          end
        valid =
          payment.id == id && payment.customer_id == invoice.customer_id &&
            payment.txn_date == txn_date.iso8601 && payment.total_amount == amount && linked
        unless valid
          raise_unexpected!("QuickBooks Payment readback did not match the submitted record.")
        end

        payment
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_customer_payment_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_customer_payment_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
