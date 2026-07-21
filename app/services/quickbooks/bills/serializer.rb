module Quickbooks
  module Bills
    class Serializer
      def self.bill(bill)
        {
          id: bill.id,
          doc_number: bill.doc_number,
          txn_date: bill.txn_date,
          due_date: bill.due_date,
          vendor_id: bill.vendor_id,
          vendor_name: bill.vendor_name,
          payable_account_id: bill.payable_account_id,
          total_amount: bill.total_amount.to_s("F"),
          balance: bill.balance.to_s("F"),
          lines:
            bill.lines.map do |line|
              {
                description: line.description,
                amount: line.amount.to_s("F"),
                account_id: line.account_id,
                account_name: line.account_name
              }
            end
        }
      end

      def self.catalog(catalog)
        {
          bills: catalog.bills.map { |bill| self.bill(bill) },
          vendor_choices:
            catalog.vendors.map { |vendor| { id: vendor.id, display_name: vendor.display_name } },
          account_choices: {
            expense: catalog.expense_accounts.map { |account| account_choice(account) },
            payable: catalog.payable_accounts.map { |account| account_choice(account) }
          }
        }
      end

      def self.account_choice(account)
        { id: account.id, display_name: account.display_name }
      end

      private_class_method :account_choice
    end
  end
end
