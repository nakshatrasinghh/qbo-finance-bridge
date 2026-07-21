module Quickbooks
  class ConnectionsController < BaseController
    OAUTH_STATE_SESSION_KEY = "quickbooks_oauth_state"
    OAUTH_STATE_TTL = 10.minutes

    before_action :set_callback_security_headers, only: :callback

    rescue_from Error, with: :redirect_quickbooks_error
    rescue_from ActiveRecord::RecordInvalid,
                ActiveRecord::RecordNotUnique,
                with: :redirect_persistence_error

    def index
      @connections = QuickbooksConnection.order(updated_at: :desc).limit(20)
      @configuration_error = configuration_error
    end

    def show
      @connection = QuickbooksConnection.find(params[:id])
      return unless @connection.connected?

      @company_info = CompanyInfo::Fetch.new(connection: @connection).call
    rescue Error => error
      @quickbooks_error = error
    end

    def connect
      state = SecureRandom.urlsafe_base64(32)
      authorization_url = configuration.authorization_url(state: state)
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
        Oauth::ExchangeAuthorizationCode.new(configuration: configuration).call(
          code: params[:code].to_s,
          realm_id: params[:realmId].to_s
        )
      redirect_to quickbooks_connection_path(connection),
                  notice:
                    "QuickBooks sandbox connected. CompanyInfo was requested for verification."
    end

    def disconnect
      connection = QuickbooksConnection.find(params[:id])
      Oauth::Disconnect.new(connection: connection, configuration: configuration).call
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

    def redirect_persistence_error(error)
      Rails.error.report(error, handled: true, severity: :warning)
      redirect_to quickbooks_connections_path,
                  status: :see_other,
                  alert: "The QuickBooks connection could not be saved."
    end
  end
end
