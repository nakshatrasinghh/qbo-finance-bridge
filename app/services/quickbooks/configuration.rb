module Quickbooks
  class Configuration
    ACCOUNTING_SCOPE = "com.intuit.quickbooks.accounting"
    AUTHORIZATION_URL = "https://appcenter.intuit.com/connect/oauth2"
    TOKEN_BASE_URL = "https://oauth.platform.intuit.com"
    TOKEN_PATH = "/oauth2/v1/tokens/bearer"
    REVOCATION_BASE_URL = "https://developer.api.intuit.com"
    REVOCATION_PATH = "/v2/oauth2/tokens/revoke"
    SANDBOX_API_BASE_URL = "https://sandbox-quickbooks.api.intuit.com"
    MINIMUM_MINOR_VERSION = 75

    def validate!
      ensure_sandbox!
      required_value!(client_id, "QUICKBOOKS_CLIENT_ID")
      required_value!(client_secret, "QUICKBOOKS_CLIENT_SECRET")
      required_value!(redirect_uri, "QUICKBOOKS_REDIRECT_URI")
      validate_redirect_uri!
      minor_version
      open_timeout
      read_timeout
      self
    end

    def ready?
      validate!
      true
    rescue Error::Configuration
      false
    end

    def environment
      ENV.fetch("QUICKBOOKS_ENV", "sandbox").presence || "sandbox"
    end

    def client_id
      ENV["QUICKBOOKS_CLIENT_ID"].presence ||
        Rails.application.credentials.dig(:quickbooks, :client_id)
    end

    def client_secret
      ENV["QUICKBOOKS_CLIENT_SECRET"].presence ||
        Rails.application.credentials.dig(:quickbooks, :client_secret)
    end

    def redirect_uri
      ENV["QUICKBOOKS_REDIRECT_URI"].presence ||
        Rails.application.credentials.dig(:quickbooks, :redirect_uri)
    end

    def minor_version
      integer_setting(
        "QUICKBOOKS_MINOR_VERSION",
        default: MINIMUM_MINOR_VERSION,
        minimum: MINIMUM_MINOR_VERSION
      )
    end

    def open_timeout
      integer_setting("QUICKBOOKS_OPEN_TIMEOUT", default: 5, minimum: 1, maximum: 30)
    end

    def read_timeout
      integer_setting("QUICKBOOKS_READ_TIMEOUT", default: 10, minimum: 1, maximum: 120)
    end

    def api_base_url
      ensure_sandbox!
      SANDBOX_API_BASE_URL
    end

    def dashboard_enabled?
      Rails.env.development? || ENV["ENABLE_QUICKBOOKS_CONNECTION_DASHBOARD"] == "true"
    end

    def authorization_url(state:)
      validate!
      uri = URI(AUTHORIZATION_URL)
      uri.query =
        URI.encode_www_form(
          client_id:,
          redirect_uri:,
          response_type: "code",
          scope: ACCOUNTING_SCOPE,
          state:
        )
      uri.to_s
    end

    private

    def ensure_sandbox!
      return if environment == "sandbox"

      raise Error::Configuration.new(
              "QuickBooks production access is disabled.",
              code: "quickbooks_environment_not_sandbox",
              http_status: :service_unavailable
            )
    end

    def required_value!(value, environment_name)
      return if value.present?

      raise Error::Configuration.new(
              "Missing #{environment_name} configuration.",
              code: "quickbooks_configuration_missing",
              http_status: :service_unavailable,
              details: {
                setting: environment_name
              }
            )
    end

    def validate_redirect_uri!
      uri = URI.parse(redirect_uri)
      absolute_uri = uri.host.present? && uri.userinfo.nil? && uri.fragment.nil?
      local_development_uri =
        Rails.env.development? && absolute_uri && uri.scheme == "http" &&
          %w[127.0.0.1 localhost].include?(uri.host)
      return if (absolute_uri && uri.scheme == "https") || local_development_uri

      raise Error::Configuration.new(
              "QUICKBOOKS_REDIRECT_URI must use HTTPS outside local development.",
              code: "quickbooks_redirect_uri_invalid",
              http_status: :service_unavailable,
              details: {
                setting: "QUICKBOOKS_REDIRECT_URI"
              }
            )
    rescue URI::InvalidURIError
      raise Error::Configuration.new(
              "Invalid QUICKBOOKS_REDIRECT_URI configuration.",
              code: "quickbooks_redirect_uri_invalid",
              http_status: :service_unavailable,
              details: {
                setting: "QUICKBOOKS_REDIRECT_URI"
              }
            )
    end

    def integer_setting(name, default:, minimum:, maximum: nil)
      value = Integer(ENV.fetch(name, default), exception: false)
      valid = value && value >= minimum && (maximum.nil? || value <= maximum)
      return value if valid

      raise Error::Configuration.new(
              "Invalid #{name} configuration.",
              code: "quickbooks_configuration_invalid",
              http_status: :service_unavailable,
              details: {
                setting: name
              }
            )
    end
  end
end
