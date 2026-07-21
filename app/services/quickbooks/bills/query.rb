module Quickbooks
  module Bills
    class Query
      EXPENSE_ACCOUNT_TYPES = ["Expense", "Cost of Goods Sold", "Other Expense"].freeze

      def initialize(connection:, client: nil)
        @connection = connection
        @client = client || Client.new(connection: connection)
      end

      def call
        accounts = Accounts::Query.new(connection: connection, client: client).call

        Details::Catalog.new(
          bills: RecordsQuery.new(connection: connection, client: client).call,
          vendors: Vendors::Query.new(connection: connection, client: client).call,
          expense_accounts:
            choices(accounts) { |account| EXPENSE_ACCOUNT_TYPES.include?(account.account_type) },
          payable_accounts:
            choices(accounts) { |account| account.account_type == "Accounts Payable" }
        )
      end

      private

      attr_reader :client, :connection

      def choices(accounts)
        accounts
          .select { |account| yield(account) }
          .map do |account|
            Details::AccountChoice.new(id: account.id, display_name: account.display_name)
          end
          .freeze
      end
    end
  end
end
