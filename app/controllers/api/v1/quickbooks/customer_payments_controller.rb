module Api
  module V1
    module Quickbooks
      class CustomerPaymentsController < BaseController
        def index
          catalog = ::Quickbooks::CustomerPayments::Query.new(connection: @connection).call

          render json: ::Quickbooks::CustomerPayments::Serializer.catalog(catalog)
        end

        def create
          result =
            ::Quickbooks::CustomerPayments::Submit.new(
              connection: @connection,
              attributes: customer_payment_params.to_h
            ).call

          render json: { customer_payment: result.customer_payment }, status: :created
        end

        private

        def customer_payment_params
          params.require(:customer_payment).permit(:invoice_id, :txn_date, :amount)
        end
      end
    end
  end
end
