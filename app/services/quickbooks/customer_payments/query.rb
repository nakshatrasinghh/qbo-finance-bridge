module Quickbooks
  module CustomerPayments
    class Query
      def initialize(connection:, client: nil)
        @connection = connection
        @client = client || Client.new(connection: connection)
      end

      def call
        open_invoices =
          Invoices::RecordsQuery
            .new(connection: connection, client: client)
            .call
            .select { |invoice| invoice.balance.positive? }
            .freeze

        Details::Catalog.new(
          payments: RecordsQuery.new(connection: connection, client: client).call,
          open_invoices: open_invoices
        )
      end

      private

      attr_reader :client, :connection
    end
  end
end
