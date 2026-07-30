module Api
  module V1
    module Quickbooks
      class TaxCodesController < BaseController
        def index
          catalog = ::Quickbooks::TaxCodes::Query.new(connection: @connection).call

          render json: ::Quickbooks::TaxCodes::Serializer.catalog(catalog)
        end

        def create
          result =
            ::Quickbooks::TaxCodes::Submit.new(
              connection: @connection,
              attributes: tax_code_params.to_h
            ).call

          render json: { tax_code: result.tax_code }, status: :created
        end

        private

        def tax_code_params
          params.require(:tax_code).permit(:name, :tax_rate_id, :applicable_on)
        end
      end
    end
  end
end
