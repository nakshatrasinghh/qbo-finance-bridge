module Api
  module V1
    module Quickbooks
      class BillsController < BaseController
        def index
          catalog = ::Quickbooks::Bills::Query.new(connection: @connection).call

          render json: ::Quickbooks::Bills::Serializer.catalog(catalog)
        end

        def create
          result =
            ::Quickbooks::Bills::Submit.new(
              connection: @connection,
              attributes: bill_params.to_h
            ).call

          render json: { bill: result.bill }, status: :created
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
      end
    end
  end
end
