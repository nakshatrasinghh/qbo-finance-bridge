module Quickbooks
  module CustomerPayments
    class Serializer
      def self.payment(payment)
        {
          id: payment.id,
          txn_date: payment.txn_date,
          customer_id: payment.customer_id,
          customer_name: payment.customer_name,
          total_amount: payment.total_amount.to_s("F"),
          unapplied_amount: payment.unapplied_amount.to_s("F"),
          applied_invoices:
            payment.applied_invoices.map do |invoice|
              { invoice_id: invoice.invoice_id, amount: invoice.amount.to_s("F") }
            end
        }
      end

      def self.catalog(catalog)
        {
          customer_payments: catalog.payments.map { |payment| self.payment(payment) },
          open_invoice_choices:
            catalog.open_invoices.map do |invoice|
              {
                id: invoice.id,
                doc_number: invoice.doc_number,
                customer_id: invoice.customer_id,
                customer_name: invoice.customer_name,
                txn_date: invoice.txn_date,
                balance: invoice.balance.to_s("F")
              }
            end
        }
      end
    end
  end
end
