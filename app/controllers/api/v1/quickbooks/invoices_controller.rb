module Api
  module V1
    module Quickbooks
      class InvoicesController < BaseController
        def index
          catalog = ::Quickbooks::Invoices::Query.new(connection: @connection).call

          render json: ::Quickbooks::Invoices::Serializer.catalog(catalog)
        end

        def create
          result =
            ::Quickbooks::Invoices::Submit.new(
              connection: @connection,
              attributes: invoice_params.to_h
            ).call

          render json: { invoice: result.invoice }, status: :created
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
      end
    end
  end
end
