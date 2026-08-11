module Quickbooks
  module BillPayments
    AppliedBill = Data.define(:bill_id, :amount)

    class Details < Data.define(
      :id,
      :txn_date,
      :vendor_id,
      :vendor_name,
      :pay_type,
      :payment_account_id,
      :payment_account_name,
      :total_amount,
      :applied_bills
    )
      AccountChoice = Data.define(:id, :display_name)
      Catalog = Data.define(:payments, :open_bills, :bank_accounts)

      def self.from_payload(payload)
        vendor = payload["VendorRef"]
        payment_account =
          if payload["PayType"] == "Check"
            payload.dig("CheckPayment", "BankAccountRef")
          else
            payload.dig("CreditCardPayment", "CCAccountRef")
          end

        new(
          id: payload["Id"].to_s,
          txn_date: payload["TxnDate"].to_s,
          vendor_id: reference_value(vendor),
          vendor_name: reference_name(vendor),
          pay_type: payload["PayType"].to_s,
          payment_account_id: reference_value(payment_account),
          payment_account_name: reference_name(payment_account),
          total_amount: decimal(payload["TotalAmt"]),
          applied_bills: Array(payload["Line"]).flat_map { |line| applied_bills(line) }.freeze
        )
      end

      def self.applied_bills(line)
        return [] unless line.is_a?(Hash)

        amount = decimal(line["Amount"])
        Array(line["LinkedTxn"]).filter_map do |linked|
          next unless linked.is_a?(Hash) && linked["TxnType"] == "Bill"

          AppliedBill.new(bill_id: linked["TxnId"].to_s, amount: amount)
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

      private_class_method :applied_bills, :decimal, :reference_name, :reference_value
    end
  end
end
