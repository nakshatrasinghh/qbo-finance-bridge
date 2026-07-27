module Quickbooks
  module JournalEntries
    class Create
      INELIGIBLE_ACCOUNT_TYPES = ["Accounts Payable", "Accounts Receivable"].freeze
      AMOUNT_PATTERN = /\A\d{1,12}(?:\.\d{1,2})?\z/

      def self.eligible_account?(account)
        account && INELIGIBLE_ACCOUNT_TYPES.exclude?(account.account_type)
      end

      def initialize(
        connection:,
        txn_date: nil,
        memo: nil,
        amount: nil,
        debit_account_id: nil,
        credit_account_id: nil,
        request_id:,
        client: nil
      )
        @connection = connection
        @txn_date_input = txn_date.to_s
        @memo = memo.to_s.strip
        @amount_input = amount.to_s.strip
        @debit_account_id = debit_account_id.to_s
        @credit_account_id = credit_account_id.to_s
        @request_id = request_id
        @client = client || Client.new(connection: connection)
        @post_attempted = false
      end

      def call
        validate_input!
        validate_accounts!

        @post_attempted = true
        response = client.post("journalentry", json: payload, params: { requestid: request_id })
        @quickbooks_entity_id = response.dig("JournalEntry", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created JournalEntry ID.")
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
                  :credit_account_id,
                  :debit_account_id,
                  :memo,
                  :request_id,
                  :txn_date

      def validate_input!
        @txn_date = Date.iso8601(@txn_date_input)
        raise_input!("Choose a valid transaction date.") unless txn_date.iso8601 == @txn_date_input
        raise_input!("Memo must be 1 to 500 characters.") unless memo.length.between?(1, 500)
        unless @amount_input.match?(AMOUNT_PATTERN)
          raise_input!("Amount must be positive with at most two decimal places.")
        end

        @amount = BigDecimal(@amount_input)
        raise_input!("Amount must be greater than zero.") unless amount.positive?
        if debit_account_id == credit_account_id
          raise_input!("Choose two different QuickBooks accounts.")
        end
        unless valid_account_id?(debit_account_id) && valid_account_id?(credit_account_id)
          raise_input!("Choose valid QuickBooks accounts.")
        end
      rescue Date::Error
        raise_input!("Choose a valid transaction date.")
      end

      def validate_accounts!
        accounts = Accounts::Query.new(connection: connection, client: client).call.index_by(&:id)
        debit_account = accounts[debit_account_id]
        credit_account = accounts[credit_account_id]
        unless eligible?(debit_account)
          raise_input!("The selected debit account is not active in QuickBooks.")
        end
        unless eligible?(credit_account)
          raise_input!("The selected credit account is not active in QuickBooks.")
        end
      end

      def eligible?(account)
        self.class.eligible_account?(account)
      end

      def valid_account_id?(value)
        value.match?(/\A\d{1,255}\z/)
      end

      def payload
        {
          "TxnDate" => txn_date.iso8601,
          "PrivateNote" => memo,
          "Line" => [
            line_payload(posting_type: "Debit", account_id: debit_account_id),
            line_payload(posting_type: "Credit", account_id: credit_account_id)
          ]
        }
      end

      def line_payload(posting_type:, account_id:)
        {
          "Description" => memo,
          "Amount" => JSON::Fragment.new(amount.to_s("F")),
          "DetailType" => "JournalEntryLineDetail",
          "JournalEntryLineDetail" => {
            "PostingType" => posting_type,
            "AccountRef" => {
              "value" => account_id
            }
          }
        }
      end

      def readback(id)
        response = client.get("journalentry/#{id}")
        journal_entry = response["JournalEntry"]
        unless journal_entry.is_a?(Hash)
          raise_unexpected!("QuickBooks returned invalid JournalEntry readback data.")
        end

        entry = Details.from_payload(journal_entry)
        expected_lines = [["Debit", debit_account_id], ["Credit", credit_account_id]]
        valid =
          entry.id == id && entry.txn_date == txn_date.iso8601 && entry.balanced? &&
            expected_lines.all? do |posting_type, account_id|
              entry.lines.any? do |line|
                line.posting_type == posting_type && line.account_id == account_id &&
                  line.amount == amount
              end
            end
        unless valid
          raise_unexpected!("QuickBooks JournalEntry readback did not match the submitted record.")
        end

        entry
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_journal_entry_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_journal_entry_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
