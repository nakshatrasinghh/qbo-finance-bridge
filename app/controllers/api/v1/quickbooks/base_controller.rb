module Api
  module V1
    module Quickbooks
      class BaseController < ::Quickbooks::BaseController
        rescue_from ::Quickbooks::Error, with: :render_quickbooks_error
        rescue_from ::Quickbooks::Error::ReconnectRequired, with: :render_quickbooks_error
        rescue_from ActionController::ParameterMissing, with: :render_missing_parameters

        before_action :disable_api_caching

        include ::Quickbooks::ConnectionScoped

        private

        def render_quickbooks_error(error)
          Rails.logger.warn(
            "QuickBooks API failed code=#{error.code} upstream_status=#{error.upstream_status || "none"}"
          )
          render json: {
                   error: {
                     code: error.code,
                     message: error.message
                   }
                 },
                 status: error.http_status
        end

        def render_missing_parameters(_error)
          render json: {
                   error: {
                     code: "invalid_request",
                     message: "Required request fields are missing."
                   }
                 },
                 status: :bad_request
        end

        def disable_api_caching
          response.set_header("Cache-Control", "no-store")
        end
      end
    end
  end
end
