module Quickbooks
  class ConnectionsController < BaseController
    OAUTH_STATE_SESSION_KEY = "quickbooks_oauth_state"
    OAUTH_STATE_TTL = 10.minutes

    include ConnectionScoped

    skip_before_action :set_quickbooks_connection, only: %i[index connect callback]
    before_action :set_callback_security_headers, only: :callback

    rescue_from Error, with: :redirect_quickbooks_error
    rescue_from Error::ReconnectRequired, with: :render_reconnect_required

    def index
      @connection = session_quickbooks_connection
      @configuration_error = configuration_error
    end

    def show
      @company_info = CompanyInfo::Fetch.new(connection: @connection).call
    rescue Error::ReconnectRequired
      raise
    rescue Error => error
      @quickbooks_error = error
    end

    def connect
      connection = session_quickbooks_connection
      if connection
        redirect_to quickbooks_connection_path(connection.id),
                    alert: "Disconnect the current sandbox before connecting another company."
        return
      end

      state = SecureRandom.urlsafe_base64(32)
      authorization_url = configuration.authorization_url(state:)
      session[OAUTH_STATE_SESSION_KEY] = {
        "value" => state,
        "expires_at" => OAUTH_STATE_TTL.from_now.to_i
      }
      redirect_to authorization_url, allow_other_host: true
    end

    def callback
      validate_oauth_state!
      raise_oauth_denial! if params[:error].present?

      connection =
        Oauth::ExchangeAuthorizationCode.new(
          configuration:,
          connection_store: quickbooks_connection_store
        ).call(code: params[:code].to_s, realm_id: params[:realmId].to_s)
      store_quickbooks_connection_session!(connection)
      redirect_to quickbooks_connection_path(connection.id),
                  notice:
                    "QuickBooks sandbox connected. CompanyInfo was requested for verification."
    end

    def disconnect
      Oauth::Disconnect.new(
        connection_id: @connection.id,
        configuration:,
        connection_store: quickbooks_connection_store
      ).call
      clear_quickbooks_connection_session!
      redirect_to quickbooks_connections_path,
                  status: :see_other,
                  notice: "QuickBooks access was revoked and local tokens were cleared."
    end

    private

    def configuration_error
      configuration.validate!
      nil
    rescue Error::Configuration => error
      error
    end

    def set_callback_security_headers
      response.set_header("Cache-Control", "no-store")
      response.set_header("Referrer-Policy", "no-referrer")
    end

    def validate_oauth_state!
      stored_state = session.delete(OAUTH_STATE_SESSION_KEY)
      expected = stored_state&.fetch("value", nil).to_s
      actual = params[:state].to_s
      expires_at = Integer(stored_state&.fetch("expires_at", nil), exception: false)
      valid = expected.present? && actual.present? && expires_at && Time.current.to_i <= expires_at
      valid &&= ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      return if valid

      raise Error::Authentication.new(
              "QuickBooks OAuth state is invalid or expired. Start the connection again.",
              code: "quickbooks_oauth_state_invalid",
              http_status: :unauthorized
            )
    end

    def raise_oauth_denial!
      error_code =
        params[:error].to_s.match?(/\A[a-z0-9_.-]{1,64}\z/i) ? params[:error].to_s : "oauth_denied"
      raise Error::Authorization.new(
              "QuickBooks authorization was denied.",
              code: error_code,
              http_status: :forbidden
            )
    end

    def redirect_quickbooks_error(error)
      Rails.logger.warn(
        "QuickBooks flow failed code=#{error.code} upstream_status=#{error.upstream_status || "none"}"
      )
      redirect_to quickbooks_connections_path, status: :see_other, alert: error.message
    end
  end
end
