module Api
  module V1
    module Quickbooks
      class BillPaymentsController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          catalog = ::Quickbooks::BillPayments::Query.new(connection: connection).call

          render json: ::Quickbooks::BillPayments::Serializer.catalog(catalog)
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::BillPayments::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: bill_payment_params.to_h
            ).call

          render_create(result)
        end

        private

        def bill_payment_params
          params.require(:bill_payment).permit(:bill_id, :bank_account_id, :txn_date, :amount)
        end

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   bill_payment: result.bill_payment,
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
