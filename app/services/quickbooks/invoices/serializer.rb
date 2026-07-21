module Quickbooks
  module Invoices
    class Serializer
      def self.invoice(invoice)
        {
          id: invoice.id,
          doc_number: invoice.doc_number,
          txn_date: invoice.txn_date,
          due_date: invoice.due_date,
          customer_id: invoice.customer_id,
          customer_name: invoice.customer_name,
          total_amount: invoice.total_amount.to_s("F"),
          balance: invoice.balance.to_s("F"),
          lines:
            invoice.lines.map do |line|
              {
                description: line.description,
                amount: line.amount.to_s("F"),
                item_id: line.item_id,
                item_name: line.item_name
              }
            end
        }
      end

      def self.catalog(catalog)
        {
          invoices: catalog.invoices.map { |invoice| self.invoice(invoice) },
          customer_choices:
            catalog.customers.map do |customer|
              { id: customer.id, display_name: customer.display_name }
            end,
          item_choices:
            catalog.items.map { |item| { id: item.id, name: item.name, item_type: item.item_type } }
        }
      end
    end
  end
end
