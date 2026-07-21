module Quickbooks
  module BillPayments
    class Create
      MONEY_PATTERN = /\A\d{1,11}(?:\.\d{1,2})?\z/

      def initialize(
        connection:,
        bill_id: nil,
        bank_account_id: nil,
        txn_date: nil,
        amount: nil,
        request_id:,
        client: nil
      )
        @connection = connection
        @bill_id = bill_id.to_s
        @bank_account_id = bank_account_id.to_s
        @txn_date_input = txn_date.to_s
        @amount_input = amount.to_s.strip
        @request_id = request_id
        @client = client || Client.new(connection: connection)
        @post_attempted = false
      end

      def call
        validate_input!
        load_references!

        @post_attempted = true
        response = client.post("billpayment", json: payload, params: { requestid: request_id })
        @quickbooks_entity_id = response.dig("BillPayment", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created BillPayment ID.")
        end

        readback(quickbooks_entity_id)
      end

      attr_reader :quickbooks_entity_id

      def post_attempted?
        @post_attempted
      end

      private

      attr_reader :amount,
                  :bank_account_id,
                  :bill,
                  :bill_id,
                  :client,
                  :connection,
                  :request_id,
                  :txn_date

      def validate_input!
        [bill_id, bank_account_id].each do |id|
          unless id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT)
            raise_input!("Choose a valid open QuickBooks Bill and bank Account.")
          end
        end

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

      def load_references!
        catalog = Query.new(connection: connection, client: client).call
        @bill = catalog.open_bills.find { |candidate| candidate.id == bill_id }
        bank_valid = catalog.bank_accounts.any? { |account| account.id == bank_account_id }
        unless bill && bank_valid
          raise_input!("The selected Bill is not open or the bank Account is not active.")
        end
        raise_input!("Payment amount cannot exceed the Bill balance.") if amount > bill.balance
      end

      def payload
        {
          "TxnDate" => txn_date.iso8601,
          "VendorRef" => {
            "value" => bill.vendor_id
          },
          "APAccountRef" => {
            "value" => bill.payable_account_id
          },
          "PayType" => "Check",
          "CheckPayment" => {
            "BankAccountRef" => {
              "value" => bank_account_id
            }
          },
          "TotalAmt" => JSON::Fragment.new(amount.to_s("F")),
          "Line" => [
            {
              "Amount" => JSON::Fragment.new(amount.to_s("F")),
              "LinkedTxn" => [{ "TxnId" => bill.id, "TxnType" => "Bill" }]
            }
          ]
        }
      end

      def readback(id)
        response = client.get("billpayment/#{id}")
        raw = response["BillPayment"]
        unless raw.is_a?(Hash)
          raise_unexpected!("QuickBooks returned invalid BillPayment readback data.")
        end

        payment = Details.from_payload(raw)
        linked =
          payment.applied_bills.find do |applied|
            applied.bill_id == bill.id && applied.amount == amount
          end
        valid =
          payment.id == id && payment.vendor_id == bill.vendor_id &&
            payment.txn_date == txn_date.iso8601 && payment.pay_type == "Check" &&
            payment.payment_account_id == bank_account_id && payment.total_amount == amount &&
            linked
        unless valid
          raise_unexpected!("QuickBooks BillPayment readback did not match the submitted record.")
        end

        payment
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_bill_payment_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_bill_payment_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
