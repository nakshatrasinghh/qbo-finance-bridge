module Quickbooks
  module InventoryItems
    class Create
      NAME_PATTERN = /\A[^:\t\r\n]+\z/
      QUANTITY_PATTERN = /\A\d{1,12}(?:\.\d{1,5})?\z/
      MONEY_PATTERN = /\A\d{1,11}(?:\.\d{1,2})?\z/

      def initialize(
        connection:,
        name: nil,
        sku: nil,
        description: nil,
        inventory_start_date: nil,
        quantity_on_hand: nil,
        unit_price: nil,
        purchase_cost: nil,
        income_account_id: nil,
        expense_account_id: nil,
        asset_account_id: nil,
        client: nil
      )
        @connection = connection
        @name = name.to_s.strip
        @sku = sku.to_s.strip
        @description = description.to_s.strip
        @inventory_start_date_input = inventory_start_date.to_s
        @quantity_input = quantity_on_hand.to_s.strip
        @unit_price_input = unit_price.to_s.strip
        @purchase_cost_input = purchase_cost.to_s.strip
        @income_account_id = income_account_id.to_s
        @expense_account_id = expense_account_id.to_s
        @asset_account_id = asset_account_id.to_s
        @client = client || Client.new(connection:)
      end

      def call
        validate_input!
        validate_accounts!

        response = client.post("item", json: payload)
        quickbooks_entity_id = response.dig("Item", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created inventory Item ID.")
        end

        readback(quickbooks_entity_id)
      end

      private

      attr_reader :asset_account_id,
                  :client,
                  :connection,
                  :description,
                  :expense_account_id,
                  :income_account_id,
                  :inventory_start_date,
                  :name,
                  :purchase_cost,
                  :quantity_on_hand,
                  :sku,
                  :unit_price

      def validate_input!
        unless name.length.between?(1, 100) && name.match?(NAME_PATTERN)
          raise_input!("Item name must be 1 to 100 characters without colon, tab, or newline.")
        end
        raise_input!("SKU must be at most 100 characters.") if sku.length > 100
        raise_input!("Description must be at most 500 characters.") if description.length > 500

        @inventory_start_date = Date.iso8601(@inventory_start_date_input)
        unless inventory_start_date.iso8601 == @inventory_start_date_input
          raise_input!("Choose a valid inventory start date.")
        end

        @quantity_on_hand = decimal_input(@quantity_input, QUANTITY_PATTERN, "Quantity on hand")
        @unit_price = optional_decimal(@unit_price_input, "Unit price")
        @purchase_cost = optional_decimal(@purchase_cost_input, "Purchase cost")

        [income_account_id, expense_account_id, asset_account_id].each do |account_id|
          unless EntityId.valid?(account_id)
            raise_input!("Choose valid QuickBooks inventory accounts.")
          end
        end
      rescue Date::Error
        raise_input!("Choose a valid inventory start date.")
      end

      def optional_decimal(value, label)
        return if value.blank?

        decimal_input(value, MONEY_PATTERN, label)
      end

      def decimal_input(value, pattern, label)
        unless value.match?(pattern)
          raise_input!("#{label} must be a non-negative decimal in the documented range.")
        end

        decimal = BigDecimal(value)
        raise_input!("#{label} must be non-negative.") if decimal.negative?
        decimal
      end

      def validate_accounts!
        accounts = Accounts::Query.new(connection:, client:).call.index_by(&:id)
        income_account = accounts[income_account_id]
        expense_account = accounts[expense_account_id]
        asset_account = accounts[asset_account_id]
        valid =
          income_account&.account_type == "Income" &&
            income_account.account_subtype == "SalesOfProductIncome" &&
            expense_account&.account_type == "Cost of Goods Sold" &&
            asset_account&.account_type == "Other Current Asset" &&
            asset_account.account_subtype == "Inventory"
        raise_input!("The selected inventory accounts are not eligible in QuickBooks.") unless valid
      end

      def payload
        result = {
          "Name" => name,
          "Type" => "Inventory",
          "InvStartDate" => inventory_start_date.iso8601,
          "QtyOnHand" => JSON::Fragment.new(quantity_on_hand.to_s("F")),
          "TrackQtyOnHand" => true,
          "IncomeAccountRef" => {
            "value" => income_account_id
          },
          "ExpenseAccountRef" => {
            "value" => expense_account_id
          },
          "AssetAccountRef" => {
            "value" => asset_account_id
          }
        }
        result["Sku"] = sku if sku.present?
        result["Description"] = description if description.present?
        result["UnitPrice"] = JSON::Fragment.new(unit_price.to_s("F")) if unit_price
        result["PurchaseCost"] = JSON::Fragment.new(purchase_cost.to_s("F")) if purchase_cost
        result
      end

      def readback(id)
        response = client.get("item/#{id}")
        item_payload = response["Item"]
        unless item_payload.is_a?(Hash)
          raise_unexpected!("QuickBooks returned invalid inventory Item readback data.")
        end

        item = Details.from_payload(item_payload)
        valid =
          item.id == id && item.name == name && item.quantity_on_hand == quantity_on_hand &&
            item.inventory_start_date == inventory_start_date.iso8601 &&
            item.income_account_id == income_account_id &&
            item.expense_account_id == expense_account_id &&
            item.asset_account_id == asset_account_id &&
            (unit_price.nil? || item.unit_price == unit_price) &&
            (purchase_cost.nil? || item.purchase_cost == purchase_cost)
        unless valid
          raise_unexpected!(
            "QuickBooks inventory Item readback did not match the submitted record."
          )
        end

        item
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_inventory_item_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_inventory_item_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
