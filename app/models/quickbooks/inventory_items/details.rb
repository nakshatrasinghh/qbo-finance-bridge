module Quickbooks
  module InventoryItems
    class Details < Data.define(
      :id,
      :name,
      :sku,
      :description,
      :quantity_on_hand,
      :unit_price,
      :purchase_cost,
      :inventory_start_date,
      :income_account_id,
      :expense_account_id,
      :asset_account_id,
      :active
    )
      AccountChoice = Data.define(:id, :display_name)
      Catalog = Data.define(:items, :income_accounts, :expense_accounts, :asset_accounts)

      def self.from_payload(payload)
        new(
          id: payload["Id"].to_s,
          name: payload["Name"].to_s,
          sku: payload["Sku"].presence,
          description: payload["Description"].presence,
          quantity_on_hand: decimal(payload["QtyOnHand"]),
          unit_price: decimal(payload["UnitPrice"]),
          purchase_cost: decimal(payload["PurchaseCost"]),
          inventory_start_date: payload["InvStartDate"].to_s,
          income_account_id: reference_id(payload["IncomeAccountRef"]),
          expense_account_id: reference_id(payload["ExpenseAccountRef"]),
          asset_account_id: reference_id(payload["AssetAccountRef"]),
          active: payload["Active"]
        )
      end

      def self.decimal(value)
        return if value.nil?

        BigDecimal(value.to_s, exception: false)
      end

      def self.reference_id(reference)
        reference.is_a?(Hash) ? reference["value"].to_s : ""
      end

      private_class_method :decimal, :reference_id
    end
  end
end
