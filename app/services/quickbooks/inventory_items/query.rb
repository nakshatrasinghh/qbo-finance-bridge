module Quickbooks
  module InventoryItems
    class Query
      MAX_RESULTS = 1_000

      def initialize(connection:, client: nil)
        @connection = connection
        @client = client || Client.new(connection: connection)
      end

      def call
        accounts = Accounts::Query.new(connection: connection, client: client).call

        Details::Catalog.new(
          items: inventory_items,
          income_accounts:
            account_choices(accounts) do |account|
              account.account_type == "Income" && account.account_subtype == "SalesOfProductIncome"
            end,
          expense_accounts:
            account_choices(accounts) { |account| account.account_type == "Cost of Goods Sold" },
          asset_accounts:
            account_choices(accounts) do |account|
              account.account_type == "Other Current Asset" &&
                account.account_subtype == "Inventory"
            end
        )
      end

      private

      attr_reader :client, :connection

      def inventory_items
        response =
          client.get(
            "query",
            params: {
              query: "SELECT * FROM Item WHERE Type = 'Inventory' MAXRESULTS #{MAX_RESULTS}"
            }
          )
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["Item"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash) && payload["Type"] == "Inventory"

            item = Details.from_payload(payload)
            valid =
              item.id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT) && item.name.present? &&
                item.quantity_on_hand &&
                item.inventory_start_date.match?(/\A\d{4}-\d{2}-\d{2}\z/) &&
                item.income_account_id.present? && item.expense_account_id.present? &&
                item.asset_account_id.present?
            raise_unexpected! unless valid

            item
          end
          .sort_by { |item| item.name.downcase }
          .freeze
      end

      def account_choices(accounts)
        accounts
          .select { |account| yield(account) }
          .map do |account|
            Details::AccountChoice.new(id: account.id, display_name: account.display_name)
          end
          .freeze
      end

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected inventory Item data.",
                code: "quickbooks_inventory_items_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
