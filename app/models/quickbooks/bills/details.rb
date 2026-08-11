module Quickbooks
  module Bills
    Line = Data.define(:description, :amount, :account_id, :account_name)

    class Details < Data.define(
      :id,
      :doc_number,
      :txn_date,
      :due_date,
      :vendor_id,
      :vendor_name,
      :payable_account_id,
      :total_amount,
      :balance,
      :lines
    )
      AccountChoice = Data.define(:id, :display_name)
      Catalog = Data.define(:bills, :vendors, :expense_accounts, :payable_accounts)

      def self.from_payload(payload)
        vendor = payload["VendorRef"]
        payable_account = payload["APAccountRef"]

        new(
          id: payload["Id"].to_s,
          doc_number: payload["DocNumber"].presence,
          txn_date: payload["TxnDate"].to_s,
          due_date: payload["DueDate"].to_s,
          vendor_id: reference_value(vendor),
          vendor_name: reference_name(vendor),
          payable_account_id: reference_value(payable_account),
          total_amount: decimal(payload["TotalAmt"]),
          balance: decimal(payload["Balance"]),
          lines: Array(payload["Line"]).filter_map { |line| build_line(line) }.freeze
        )
      end

      def self.build_line(payload)
        unless payload.is_a?(Hash) && payload["DetailType"] == "AccountBasedExpenseLineDetail"
          return
        end

        account = payload.dig("AccountBasedExpenseLineDetail", "AccountRef")
        Line.new(
          description: payload["Description"].presence,
          amount: decimal(payload["Amount"]),
          account_id: reference_value(account),
          account_name: reference_name(account)
        )
      end

      def self.decimal(value)
        BigDecimal(value.to_s, exception: false)
      end

      def self.reference_value(reference)
        reference.is_a?(Hash) ? reference["value"].to_s : ""
      end

      def self.reference_name(reference)
        reference.is_a?(Hash) ? reference["name"].presence : nil
      end

      private_class_method :build_line, :decimal, :reference_name, :reference_value
    end
  end
end
