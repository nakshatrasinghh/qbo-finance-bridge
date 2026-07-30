module Quickbooks
  class BaseController < ApplicationController
    CONNECTION_SESSION_KEY = "quickbooks_connection_id"

    before_action :ensure_dashboard_enabled!
    rescue_from Error::ReconnectRequired, with: :render_reconnect_required

    private

    def configuration
      @configuration ||= Configuration.new
    end

    def quickbooks_connection_store
      @quickbooks_connection_store ||= SandboxConnectionStore.configured
    end

    def session_quickbooks_connection
      connection_id = session_quickbooks_connection_id
      return unless connection_id

      connection = quickbooks_connection_store.fetch(connection_id)
      clear_quickbooks_connection_session! unless connection
      connection
    end

    def store_quickbooks_connection_session!(connection)
      session[CONNECTION_SESSION_KEY] = connection.id
    end

    def clear_quickbooks_connection_session!
      session.delete(CONNECTION_SESSION_KEY)
    end

    def ensure_dashboard_enabled!
      return if configuration.dashboard_enabled?

      raise ActionController::RoutingError, "Not Found"
    end

    def session_quickbooks_connection_id
      connection_id = session[CONNECTION_SESSION_KEY]
      connection_id if connection_id.is_a?(String)
    end

    def render_reconnect_required(error)
      render plain: error.message, status: error.http_status
    end
  end
end
