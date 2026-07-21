module Quickbooks
  module BillPayments
    class Query
      def initialize(connection:, client: nil)
        @connection = connection
        @client = client || Client.new(connection: connection)
      end

      def call
        open_bills =
          Bills::RecordsQuery
            .new(connection: connection, client: client)
            .call
            .select { |bill| bill.balance.positive? }
            .freeze
        bank_accounts =
          Accounts::Query
            .new(connection: connection, client: client)
            .call
            .filter_map do |account|
              next unless account.account_type == "Bank"

              Details::AccountChoice.new(id: account.id, display_name: account.display_name)
            end
            .freeze

        Details::Catalog.new(
          payments: RecordsQuery.new(connection: connection, client: client).call,
          open_bills: open_bills,
          bank_accounts: bank_accounts
        )
      end

      private

      attr_reader :client, :connection
    end
  end
end
