module Quickbooks
  module Invoices
    Line = Data.define(:description, :amount, :item_id, :item_name)

    class Details < Data.define(
      :id,
      :doc_number,
      :txn_date,
      :due_date,
      :customer_id,
      :customer_name,
      :total_amount,
      :balance,
      :lines
    )
      Catalog = Data.define(:invoices, :customers, :items)

      def self.from_payload(payload)
        customer = payload["CustomerRef"]

        new(
          id: payload["Id"].to_s,
          doc_number: payload["DocNumber"].presence,
          txn_date: payload["TxnDate"].to_s,
          due_date: payload["DueDate"].to_s,
          customer_id: reference_value(customer),
          customer_name: reference_name(customer),
          total_amount: decimal(payload["TotalAmt"]),
          balance: decimal(payload["Balance"]),
          lines: Array(payload["Line"]).filter_map { |line| build_line(line) }.freeze
        )
      end

      def self.build_line(payload)
        return unless payload.is_a?(Hash) && payload["DetailType"] == "SalesItemLineDetail"

        item = payload.dig("SalesItemLineDetail", "ItemRef")
        Line.new(
          description: payload["Description"].presence,
          amount: decimal(payload["Amount"]),
          item_id: reference_value(item),
          item_name: reference_name(item)
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
