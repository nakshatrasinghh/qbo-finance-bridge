module Quickbooks
  module Invoices
    class Create
      MONEY_PATTERN = /\A\d{1,11}(?:\.\d{1,2})?\z/

      def initialize(
        connection:,
        customer_id: nil,
        item_id: nil,
        txn_date: nil,
        due_date: nil,
        amount: nil,
        description: nil,
        request_id:,
        client: nil
      )
        @connection = connection
        @customer_id = customer_id.to_s
        @item_id = item_id.to_s
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
        response = client.post("invoice", json: payload, params: { requestid: request_id })
        @quickbooks_entity_id = response.dig("Invoice", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created Invoice ID.")
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
                  :customer_id,
                  :description,
                  :due_date,
                  :item_id,
                  :request_id,
                  :txn_date

      def validate_input!
        [customer_id, item_id].each do |id|
          unless id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT)
            raise_input!("Choose a valid QuickBooks Customer and sales Item.")
          end
        end
        @txn_date = exact_date(@txn_date_input, "Invoice date")
        @due_date = exact_date(@due_date_input, "Due date")
        raise_input!("Due date cannot be before the invoice date.") if due_date < txn_date
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
        customer_valid =
          Customers::Query
            .new(connection: connection, client: client)
            .call
            .any? { |customer| customer.id == customer_id }
        item_valid =
          Items::SalesChoices
            .new(connection: connection, client: client)
            .call
            .any? { |item| item.id == item_id }
        unless customer_valid && item_valid
          raise_input!("The selected Customer or sales Item is not currently active in QuickBooks.")
        end
      end

      def payload
        {
          "TxnDate" => txn_date.iso8601,
          "DueDate" => due_date.iso8601,
          "CustomerRef" => {
            "value" => customer_id
          },
          "Line" => [
            {
              "Amount" => JSON::Fragment.new(amount.to_s("F")),
              "Description" => description,
              "DetailType" => "SalesItemLineDetail",
              "SalesItemLineDetail" => {
                "ItemRef" => {
                  "value" => item_id
                }
              }
            }
          ]
        }
      end

      def readback(id)
        response = client.get("invoice/#{id}")
        raw = response["Invoice"]
        unless raw.is_a?(Hash)
          raise_unexpected!("QuickBooks returned invalid Invoice readback data.")
        end

        invoice = Details.from_payload(raw)
        matching_line =
          invoice.lines.find { |line| line.item_id == item_id && line.amount == amount }
        valid =
          invoice.id == id && invoice.customer_id == customer_id &&
            invoice.txn_date == txn_date.iso8601 && invoice.due_date == due_date.iso8601 &&
            matching_line && invoice.total_amount && invoice.balance
        unless valid
          raise_unexpected!("QuickBooks Invoice readback did not match the submitted record.")
        end

        invoice
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_invoice_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_invoice_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
