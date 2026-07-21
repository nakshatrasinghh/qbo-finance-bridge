module Quickbooks
  module InventoryItems
    class Serializer
      def self.item(item)
        {
          id: item.id,
          name: item.name,
          sku: item.sku,
          description: item.description,
          quantity_on_hand: decimal_string(item.quantity_on_hand),
          unit_price: decimal_string(item.unit_price),
          purchase_cost: decimal_string(item.purchase_cost),
          inventory_start_date: item.inventory_start_date,
          income_account_id: item.income_account_id,
          expense_account_id: item.expense_account_id,
          asset_account_id: item.asset_account_id,
          active: item.active
        }
      end

      def self.catalog(catalog)
        {
          inventory_items: catalog.items.map { |item| self.item(item) },
          account_choices: {
            income: catalog.income_accounts.map { |account| account_choice(account) },
            expense: catalog.expense_accounts.map { |account| account_choice(account) },
            asset: catalog.asset_accounts.map { |account| account_choice(account) }
          }
        }
      end

      def self.account_choice(account)
        { id: account.id, display_name: account.display_name }
      end

      def self.decimal_string(value)
        value&.to_s("F")
      end

      private_class_method :account_choice, :decimal_string
    end
  end
end
