module Api
  module V1
    module Quickbooks
      class InventoryItemsController < BaseController
        def index
          catalog = ::Quickbooks::InventoryItems::Query.new(connection: @connection).call

          render json: ::Quickbooks::InventoryItems::Serializer.catalog(catalog)
        end

        def create
          result =
            ::Quickbooks::InventoryItems::Submit.new(
              connection: @connection,
              attributes: inventory_item_params.to_h
            ).call

          render json: { inventory_item: result.inventory_item }, status: :created
        end

        private

        def inventory_item_params
          params.require(:inventory_item).permit(
            :name,
            :sku,
            :description,
            :inventory_start_date,
            :quantity_on_hand,
            :unit_price,
            :purchase_cost,
            :income_account_id,
            :expense_account_id,
            :asset_account_id
          )
        end
      end
    end
  end
end
