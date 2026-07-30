module Api
  module V1
    module Quickbooks
      class CustomersController < BaseController
        def index
          customers = ::Quickbooks::Customers::Query.new(connection: @connection).call

          render json: {
                   customers:
                     customers.map { |customer| ::Quickbooks::Customers::Serializer.call(customer) }
                 }
        end

        def create
          result =
            ::Quickbooks::Customers::Submit.new(
              connection: @connection,
              attributes: customer_params.to_h
            ).call

          render json: { customer: result.customer }, status: :created
        end

        private

        def customer_params
          params.require(:customer).permit(:display_name, :company_name, :email, :phone)
        end
      end
    end
  end
end
