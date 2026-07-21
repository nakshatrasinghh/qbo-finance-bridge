module Api
  module V1
    module Quickbooks
      class InvoicesController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          catalog = ::Quickbooks::Invoices::Query.new(connection: connection).call

          render json: ::Quickbooks::Invoices::Serializer.catalog(catalog)
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::Invoices::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: invoice_params.to_h
            ).call

          render_create(result)
        end

        private

        def invoice_params
          params.require(:invoice).permit(
            :customer_id,
            :item_id,
            :txn_date,
            :due_date,
            :amount,
            :description
          )
        end

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   invoice: result.invoice,
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
