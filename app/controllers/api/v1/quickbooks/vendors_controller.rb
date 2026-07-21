module Api
  module V1
    module Quickbooks
      class VendorsController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          vendors = ::Quickbooks::Vendors::Query.new(connection: connection).call

          render json: {
                   vendors: vendors.map { |vendor| ::Quickbooks::Vendors::Serializer.call(vendor) }
                 }
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::Vendors::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: vendor_params.to_h
            ).call

          render_create(result)
        end

        private

        def vendor_params
          params.require(:vendor).permit(:display_name, :company_name, :email, :phone)
        end

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   vendor: result.vendor,
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
