require "base64"

module Quickbooks
  module Oauth
    class TokenClient
      def initialize(configuration: Configuration.new, token_http: nil, revocation_http: nil)
        @configuration = configuration
        @token_http = token_http || build_http(Configuration::TOKEN_BASE_URL, form_encoded: true)
        @revocation_http = revocation_http || build_http(Configuration::REVOCATION_BASE_URL)
      end

      def exchange(code:)
        configuration.validate!
        response =
          instrument(:exchange) do
            token_http.post(Configuration::TOKEN_PATH) do |request|
              apply_common_headers(request)
              request.body = {
                grant_type: "authorization_code",
                code: code,
                redirect_uri: configuration.redirect_uri
              }
            end
          end
        token_set_from(response)
      rescue Faraday::TimeoutError
        raise_timeout
      rescue Faraday::ConnectionFailed, Faraday::SSLError
        raise_unavailable
      end

      def refresh(refresh_token:)
        configuration.validate!
        response =
          instrument(:refresh) do
            token_http.post(Configuration::TOKEN_PATH) do |request|
              apply_common_headers(request)
              request.body = { grant_type: "refresh_token", refresh_token: refresh_token }
            end
          end
        token_set_from(response)
      rescue Faraday::TimeoutError
        raise_timeout
      rescue Faraday::ConnectionFailed, Faraday::SSLError
        raise_unavailable
      end

      def revoke(token:)
        configuration.validate!
        response =
          instrument(:revoke) do
            revocation_http.post(Configuration::REVOCATION_PATH) do |request|
              apply_common_headers(request)
              request.headers["Content-Type"] = "application/json"
              request.body = JSON.generate(token: token)
            end
          end

        return true if response.success?

        raise_oauth_error(response)
      rescue Faraday::TimeoutError
        raise_timeout
      rescue Faraday::ConnectionFailed, Faraday::SSLError
        raise_unavailable
      end

      private

      attr_reader :configuration, :revocation_http, :token_http

      def build_http(base_url, form_encoded: false)
        Faraday.new(url: base_url) do |faraday|
          faraday.request :url_encoded if form_encoded
          faraday.options.open_timeout = configuration.open_timeout
          faraday.options.timeout = configuration.read_timeout
          faraday.adapter Faraday.default_adapter
        end
      end

      def apply_common_headers(request)
        credentials =
          Base64.strict_encode64("#{configuration.client_id}:#{configuration.client_secret}")
        request.headers["Accept"] = "application/json"
        request.headers["Authorization"] = "Basic #{credentials}"
      end

      def instrument(operation)
        payload = { operation: operation }
        ActiveSupport::Notifications.instrument("oauth.quickbooks", payload) do
          response = yield
          payload[:status] = response.status
          response
        end
      end

      def token_set_from(response)
        return TokenSet.from_payload(parse_json(response.body)) if response.success?

        raise_oauth_error(response)
      end

      def parse_json(body)
        JSON.parse(body)
      rescue JSON::ParserError, TypeError
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned malformed JSON.",
                code: "quickbooks_malformed_json",
                http_status: :bad_gateway
              )
      end

      def raise_oauth_error(response, payload: nil)
        if response.status >= 500
          raise Error::Unavailable.new(
                  "QuickBooks OAuth is unavailable.",
                  code: "quickbooks_oauth_unavailable",
                  http_status: :service_unavailable,
                  upstream_status: response.status
                )
        end

        payload ||= parse_error_payload(response.body)
        oauth_error = safe_oauth_error(payload["error"])
        error_class = response.status == 429 ? Error::RateLimit : Error::Authentication
        message =
          (
            if response.status == 429
              "QuickBooks temporarily rate limited OAuth."
            else
              "QuickBooks authorization failed."
            end
          )

        raise error_class.new(
                message,
                code: oauth_error || "quickbooks_oauth_error",
                http_status: response.status == 429 ? :too_many_requests : :unauthorized,
                details: oauth_error ? { oauth_error: oauth_error } : {},
                upstream_status: response.status
              )
      end

      def parse_error_payload(body)
        payload = JSON.parse(body)
        payload.is_a?(Hash) ? payload : {}
      rescue JSON::ParserError, TypeError
        {}
      end

      def safe_oauth_error(value)
        error = value.to_s
        error if error.match?(/\A[a-z0-9_.-]{1,64}\z/i)
      end

      def raise_timeout
        raise Error::Timeout.new(
                "QuickBooks OAuth timed out.",
                code: "quickbooks_oauth_timeout",
                http_status: :gateway_timeout
              )
      end

      def raise_unavailable
        raise Error::Unavailable.new(
                "QuickBooks OAuth is unavailable.",
                code: "quickbooks_oauth_unavailable",
                http_status: :service_unavailable
              )
      end
    end
  end
end
