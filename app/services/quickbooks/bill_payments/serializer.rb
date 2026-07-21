module Quickbooks
  module BillPayments
    class Serializer
      def self.payment(payment)
        {
          id: payment.id,
          txn_date: payment.txn_date,
          vendor_id: payment.vendor_id,
          vendor_name: payment.vendor_name,
          pay_type: payment.pay_type,
          payment_account_id: payment.payment_account_id,
          payment_account_name: payment.payment_account_name,
          total_amount: payment.total_amount.to_s("F"),
          applied_bills:
            payment.applied_bills.map do |bill|
              { bill_id: bill.bill_id, amount: bill.amount.to_s("F") }
            end
        }
      end

      def self.catalog(catalog)
        {
          bill_payments: catalog.payments.map { |payment| self.payment(payment) },
          open_bill_choices:
            catalog.open_bills.map do |bill|
              {
                id: bill.id,
                doc_number: bill.doc_number,
                vendor_id: bill.vendor_id,
                vendor_name: bill.vendor_name,
                txn_date: bill.txn_date,
                balance: bill.balance.to_s("F")
              }
            end,
          bank_account_choices:
            catalog.bank_accounts.map do |account|
              { id: account.id, display_name: account.display_name }
            end
        }
      end
    end
  end
end
