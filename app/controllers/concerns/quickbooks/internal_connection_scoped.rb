require "digest"

module Quickbooks
  module InternalConnectionScoped
    extend ActiveSupport::Concern

    included do
      skip_before_action :ensure_dashboard_enabled!
      skip_before_action :set_quickbooks_connection
      prepend_before_action :authorize_internal_quickbooks_request!
      before_action :set_current_quickbooks_connection!
      after_action :set_quickbooks_connection_generation!
    end

    private

    def authorize_internal_quickbooks_request!
      mode = Rails.application.config.x.quickbooks.internal_api_auth_mode
      return if mode == "loopback" && request.local?

      raise ActionController::RoutingError, "Not Found"
    end

    def set_current_quickbooks_connection!
      @connection = quickbooks_connection_store.fetch_current!
    end

    def set_quickbooks_connection_generation!
      response.set_header("X-QBO-Connection-Generation", Digest::SHA256.hexdigest(@connection.id))
    end

    def render_quickbooks_error(error)
      Rails.logger.warn(
        "QuickBooks internal API failed code=#{error.code} " \
          "upstream_status=#{error.upstream_status || "none"}"
      )
      status = error.is_a?(Error::ReconnectRequired) ? :conflict : error.http_status
      render json: { error: { code: error.code, message: error.message } }, status:
    end
  end
end
