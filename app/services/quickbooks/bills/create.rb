module Quickbooks
  module Bills
    class Create
      MONEY_PATTERN = /\A\d{1,11}(?:\.\d{1,2})?\z/

      def initialize(
        connection:,
        vendor_id: nil,
        expense_account_id: nil,
        payable_account_id: nil,
        txn_date: nil,
        due_date: nil,
        amount: nil,
        description: nil,
        request_id:,
        client: nil
      )
        @connection = connection
        @vendor_id = vendor_id.to_s
        @expense_account_id = expense_account_id.to_s
        @payable_account_id = payable_account_id.to_s
        @txn_date_input = txn_date.to_s
        @due_date_input = due_date.to_s
        @amount_input = amount.to_s.strip
        @description = description.to_s.strip
        @request_id = request_id
        @client = client || Client.new(connection: connection)
        @post_attempted = false
      end

      def call
        validate_input!
        validate_references!

        @post_attempted = true
        response = client.post("bill", json: payload, params: { requestid: request_id })
        @quickbooks_entity_id = response.dig("Bill", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created Bill ID.")
        end

        readback(quickbooks_entity_id)
      end

      attr_reader :quickbooks_entity_id

      def post_attempted?
        @post_attempted
      end

      private

      attr_reader :amount,
                  :client,
                  :connection,
                  :description,
                  :due_date,
                  :expense_account_id,
                  :payable_account_id,
                  :request_id,
                  :txn_date,
                  :vendor_id

      def validate_input!
        [vendor_id, expense_account_id, payable_account_id].each do |id|
          unless id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT)
            raise_input!("Choose a valid QuickBooks Vendor and Accounts.")
          end
        end
        @txn_date = exact_date(@txn_date_input, "Bill date")
        @due_date = exact_date(@due_date_input, "Due date")
        raise_input!("Due date cannot be before the bill date.") if due_date < txn_date
        unless description.length.between?(1, 500)
          raise_input!("Description must be 1 to 500 characters.")
        end
        unless @amount_input.match?(MONEY_PATTERN)
          raise_input!("Amount must be a positive decimal with at most two places.")
        end

        @amount = BigDecimal(@amount_input)
        raise_input!("Amount must be greater than zero.") unless amount.positive?
      end

      def exact_date(value, label)
        date = Date.iso8601(value)
        return date if date.iso8601 == value

        raise_input!("#{label} must be an ISO 8601 date.")
      rescue Date::Error
        raise_input!("#{label} must be an ISO 8601 date.")
      end

      def validate_references!
        catalog = Query.new(connection: connection, client: client).call
        valid =
          catalog.vendors.any? { |vendor| vendor.id == vendor_id } &&
            catalog.expense_accounts.any? { |account| account.id == expense_account_id } &&
            catalog.payable_accounts.any? { |account| account.id == payable_account_id }
        unless valid
          raise_input!("The selected Vendor or Accounts are not currently eligible in QuickBooks.")
        end
      end

      def payload
        {
          "TxnDate" => txn_date.iso8601,
          "DueDate" => due_date.iso8601,
          "VendorRef" => {
            "value" => vendor_id
          },
          "APAccountRef" => {
            "value" => payable_account_id
          },
          "Line" => [
            {
              "Amount" => JSON::Fragment.new(amount.to_s("F")),
              "Description" => description,
              "DetailType" => "AccountBasedExpenseLineDetail",
              "AccountBasedExpenseLineDetail" => {
                "AccountRef" => {
                  "value" => expense_account_id
                }
              }
            }
          ]
        }
      end

      def readback(id)
        response = client.get("bill/#{id}")
        raw = response["Bill"]
        raise_unexpected!("QuickBooks returned invalid Bill readback data.") unless raw.is_a?(Hash)

        bill = Details.from_payload(raw)
        matching_line =
          bill.lines.find { |line| line.account_id == expense_account_id && line.amount == amount }
        valid =
          bill.id == id && bill.vendor_id == vendor_id &&
            bill.payable_account_id == payable_account_id && bill.txn_date == txn_date.iso8601 &&
            bill.due_date == due_date.iso8601 && matching_line && bill.total_amount && bill.balance
        unless valid
          raise_unexpected!("QuickBooks Bill readback did not match the submitted record.")
        end

        bill
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_bill_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_bill_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
