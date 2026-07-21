module Api
  module V1
    module Quickbooks
      class InventoryItemsController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          catalog = ::Quickbooks::InventoryItems::Query.new(connection: connection).call

          render json: ::Quickbooks::InventoryItems::Serializer.catalog(catalog)
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::InventoryItems::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: inventory_item_params.to_h
            ).call

          render_create(result)
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

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   inventory_item: result.inventory_item,
                   idempotency: {
                     replayed: result.replayed,
                     operation_id: result.operation.id
                   }
                 },
                 status: result.replayed ? :ok : :created
        end
      end
    end
  end
end
