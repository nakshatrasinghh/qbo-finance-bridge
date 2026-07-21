module Api
  module V1
    module Quickbooks
      class CustomerPaymentsController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          catalog = ::Quickbooks::CustomerPayments::Query.new(connection: connection).call

          render json: ::Quickbooks::CustomerPayments::Serializer.catalog(catalog)
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::CustomerPayments::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: customer_payment_params.to_h
            ).call

          render_create(result)
        end

        private

        def customer_payment_params
          params.require(:customer_payment).permit(:invoice_id, :txn_date, :amount)
        end

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   customer_payment: result.customer_payment,
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
