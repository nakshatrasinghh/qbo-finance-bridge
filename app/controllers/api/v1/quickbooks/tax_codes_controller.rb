module Api
  module V1
    module Quickbooks
      class TaxCodesController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          catalog = ::Quickbooks::TaxCodes::Query.new(connection: connection).call

          render json: ::Quickbooks::TaxCodes::Serializer.catalog(catalog)
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::TaxCodes::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: tax_code_params.to_h
            ).call

          render_create(result)
        end

        private

        def tax_code_params
          params.require(:tax_code).permit(:name, :tax_rate_id, :applicable_on)
        end

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   tax_code: result.tax_code,
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
