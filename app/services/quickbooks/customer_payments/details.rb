module Quickbooks
  module CustomerPayments
    AppliedInvoice = Data.define(:invoice_id, :amount)

    class Details < Data.define(
      :id,
      :txn_date,
      :customer_id,
      :customer_name,
      :total_amount,
      :unapplied_amount,
      :applied_invoices
    )
      Catalog = Data.define(:payments, :open_invoices)

      def self.from_payload(payload)
        customer = payload["CustomerRef"]

        new(
          id: payload["Id"].to_s,
          txn_date: payload["TxnDate"].to_s,
          customer_id: reference_value(customer),
          customer_name: reference_name(customer),
          total_amount: decimal(payload["TotalAmt"]),
          unapplied_amount: decimal(payload["UnappliedAmt"]),
          applied_invoices: Array(payload["Line"]).flat_map { |line| applied_invoices(line) }.freeze
        )
      end

      def self.applied_invoices(line)
        return [] unless line.is_a?(Hash)

        amount = decimal(line["Amount"])
        Array(line["LinkedTxn"]).filter_map do |linked|
          next unless linked.is_a?(Hash) && linked["TxnType"] == "Invoice"

          AppliedInvoice.new(invoice_id: linked["TxnId"].to_s, amount: amount)
        end
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

      private_class_method :applied_invoices, :decimal, :reference_name, :reference_value
    end
  end
end
