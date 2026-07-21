module Quickbooks
  module Invoices
    class Query
      def initialize(connection:, client: nil)
        @connection = connection
        @client = client || Client.new(connection: connection)
      end

      def call
        Details::Catalog.new(
          invoices: RecordsQuery.new(connection: connection, client: client).call,
          customers: Customers::Query.new(connection: connection, client: client).call,
          items: Items::SalesChoices.new(connection: connection, client: client).call
        )
      end

      private

      attr_reader :client, :connection
    end
  end
end
