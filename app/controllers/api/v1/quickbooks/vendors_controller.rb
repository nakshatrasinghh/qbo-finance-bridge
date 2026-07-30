module Api
  module V1
    module Quickbooks
      class VendorsController < BaseController
        def index
          vendors = ::Quickbooks::Vendors::Query.new(connection: @connection).call

          render json: {
                   vendors: vendors.map { |vendor| ::Quickbooks::Vendors::Serializer.call(vendor) }
                 }
        end

        def create
          result =
            ::Quickbooks::Vendors::Submit.new(
              connection: @connection,
              attributes: vendor_params.to_h
            ).call

          render json: { vendor: result.vendor }, status: :created
        end

        private

        def vendor_params
          params.require(:vendor).permit(:display_name, :company_name, :email, :phone)
        end
      end
    end
  end
end
