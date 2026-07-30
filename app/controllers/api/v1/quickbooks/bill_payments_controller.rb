module Api
  module V1
    module Quickbooks
      class BillPaymentsController < BaseController
        def index
          catalog = ::Quickbooks::BillPayments::Query.new(connection: @connection).call

          render json: ::Quickbooks::BillPayments::Serializer.catalog(catalog)
        end

        def create
          result =
            ::Quickbooks::BillPayments::Submit.new(
              connection: @connection,
              attributes: bill_payment_params.to_h
            ).call

          render json: { bill_payment: result.bill_payment }, status: :created
        end

        private

        def bill_payment_params
          params.require(:bill_payment).permit(:bill_id, :bank_account_id, :txn_date, :amount)
        end
      end
    end
  end
end
