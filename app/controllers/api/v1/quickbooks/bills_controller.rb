module Api
  module V1
    module Quickbooks
      class BillsController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          catalog = ::Quickbooks::Bills::Query.new(connection: connection).call

          render json: ::Quickbooks::Bills::Serializer.catalog(catalog)
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::Bills::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: bill_params.to_h
            ).call

          render_create(result)
        end

        private

        def bill_params
          params.require(:bill).permit(
            :vendor_id,
            :expense_account_id,
            :payable_account_id,
            :txn_date,
            :due_date,
            :amount,
            :description
          )
        end

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   bill: result.bill,
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
