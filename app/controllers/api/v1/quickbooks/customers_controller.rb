module Api
  module V1
    module Quickbooks
      class CustomersController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          customers = ::Quickbooks::Customers::Query.new(connection: connection).call

          render json: {
                   customers:
                     customers.map { |customer| ::Quickbooks::Customers::Serializer.call(customer) }
                 }
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::Customers::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: customer_params.to_h
            ).call

          render_create(result)
        end

        private

        def customer_params
          params.require(:customer).permit(:display_name, :company_name, :email, :phone)
        end

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   customer: result.customer,
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
