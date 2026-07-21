module Quickbooks
  class Client
    def initialize(connection:, configuration: Configuration.new, token_client: nil, http: nil)
      @connection = connection
      @configuration = configuration
      @token_client = token_client || Oauth::TokenClient.new(configuration: configuration)
      @http = http || build_http
    end

    def get(path, params: {})
      validate_request!(path)
      refreshed = false

      if connection.access_token_expired?
        refresh_access_token!
        refreshed = true
      end

      response = perform_get(path, params:, retried: false)
      if response.status == 401 && !refreshed
        refresh_access_token!
        response = perform_get(path, params:, retried: true)
      end

      parse_response(response)
    end

    def post(path, json:, params: {})
      validate_request!(path)
      body = serialize_json(json)

      refresh_access_token! if connection.access_token_expired?

      parse_response(perform_post(path, params:, body:))
    end

    private

    attr_reader :configuration, :connection, :http, :token_client

    def build_http
      Faraday.new(url: configuration.api_base_url) do |faraday|
        faraday.options.open_timeout = configuration.open_timeout
        faraday.options.timeout = configuration.read_timeout
        faraday.adapter Faraday.default_adapter
      end
    end

    def validate_request!(path)
      configuration.validate!
      ensure_connection_active!

      return if path.to_s.match?(%r{\A/?[a-z0-9_-]+(?:/[a-z0-9_-]+)*\z}i)

      raise Error::Configuration.new(
              "QuickBooks request path is invalid.",
              code: "quickbooks_request_path_invalid",
              http_status: :internal_server_error
            )
    end

    def perform_get(path, params:, retried:)
      perform_request(path:, params:, method: "GET", retried:) do |endpoint, request_params|
        http.get(endpoint, request_params) do |request|
          request.headers["Accept"] = "application/json"
          request.headers["Authorization"] = "Bearer #{connection.access_token}"
        end
      end
    end

    def perform_post(path, params:, body:)
      perform_request(path:, params:, method: "POST", retried: false) do |endpoint, request_params|
        http.post(endpoint, request_params) do |request|
          request.headers["Accept"] = "application/json"
          request.headers["Authorization"] = "Bearer #{connection.access_token}"
          request.headers["Content-Type"] = "application/json"
          request.body = body
        end
      end
    end

    def perform_request(path:, params:, method:, retried:)
      endpoint = "/v3/company/#{connection.realm_id}/#{path.to_s.delete_prefix("/")}"
      request_params = params.merge(minorversion: configuration.minor_version)
      payload = {
        connection_id: connection.id,
        realm_id: connection.realm_id,
        method: method,
        path: endpoint,
        request_id: SecureRandom.uuid,
        retried: retried
      }

      ActiveSupport::Notifications.instrument("request.quickbooks", payload) do
        response = yield(endpoint, request_params)
        payload[:status] = response.status
        payload[:intuit_tid] = response.headers["intuit_tid"].presence
        response
      end
    rescue Faraday::TimeoutError
      raise Error::Timeout.new(
              "QuickBooks API request timed out.",
              code: "quickbooks_timeout",
              http_status: :gateway_timeout
            )
    rescue Faraday::ConnectionFailed, Faraday::SSLError
      raise Error::Unavailable.new(
              "QuickBooks API is unavailable.",
              code: "quickbooks_unavailable",
              http_status: :service_unavailable
            )
    end

    def serialize_json(json)
      unless json.is_a?(Hash)
        raise Error::Configuration.new(
                "QuickBooks JSON payload must be an object.",
                code: "quickbooks_json_payload_invalid",
                http_status: :internal_server_error
              )
      end

      JSON.generate(json)
    rescue JSON::GeneratorError
      raise Error::Configuration.new(
              "QuickBooks JSON payload could not be encoded.",
              code: "quickbooks_json_payload_invalid",
              http_status: :internal_server_error
            )
    end

    def refresh_access_token!
      expected_access_token = connection.access_token
      expected_refresh_token = connection.refresh_token
      begin
        token_set = token_client.refresh(refresh_token: expected_refresh_token)
      rescue Error::Authentication
        connection.reload
        credentials_changed =
          connection.access_token != expected_access_token ||
            connection.refresh_token != expected_refresh_token
        raise unless credentials_changed && !connection.access_token_expired?
      else
        connection.with_lock do
          connection.reload
          credentials_unchanged =
            connection.access_token == expected_access_token &&
              connection.refresh_token == expected_refresh_token
          connection.store_refreshed_tokens!(token_set: token_set) if credentials_unchanged
        end
        connection.reload
      end

      ensure_connection_active!
    end

    def ensure_connection_active!
      return if connection.connected? && connection.environment == configuration.environment

      raise Error::Authentication.new(
              "QuickBooks connection is not active.",
              code: "quickbooks_connection_inactive",
              http_status: :unauthorized
            )
    end

    def parse_response(response)
      return parse_json(response.body) if response.success?

      raise_api_error(response, parse_error_payload(response.body))
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

    def parse_error_payload(body)
      payload = JSON.parse(body)
      payload.is_a?(Hash) ? payload : {}
    rescue JSON::ParserError, TypeError
      {}
    end

    def raise_api_error(response, payload)
      details = fault_details(payload)
      attributes = {
        code: details[:quickbooks_code] || "quickbooks_upstream_error",
        details: details,
        upstream_status: response.status
      }

      error_class, message, http_status = error_mapping(response.status)
      raise error_class.new(message, http_status: http_status, **attributes)
    end

    def error_mapping(status)
      case status
      when 400, 422
        [Error::Validation, "QuickBooks rejected the request.", :unprocessable_entity]
      when 401
        [Error::Authentication, "QuickBooks authentication failed.", :unauthorized]
      when 403
        [Error::Authorization, "QuickBooks denied access.", :forbidden]
      when 404
        [Error::NotFound, "QuickBooks resource was not found.", :not_found]
      when 409
        [Error::Conflict, "QuickBooks reported a conflict.", :conflict]
      when 429
        [Error::RateLimit, "QuickBooks rate limit was reached.", :too_many_requests]
      when 500..599
        [Error::Unavailable, "QuickBooks API is unavailable.", :service_unavailable]
      else
        [Error::UnexpectedResponse, "QuickBooks returned an unexpected response.", :bad_gateway]
      end
    end

    def fault_details(payload)
      fault = payload["Fault"]
      error = fault.is_a?(Hash) && Array(fault["Error"]).first
      quickbooks_code = error.is_a?(Hash) ? safe_code(error["code"]) : nil
      fault_type = fault.is_a?(Hash) ? safe_code(fault["type"]) : nil
      { quickbooks_code: quickbooks_code, fault_type: fault_type }.compact
    end

    def safe_code(value)
      code = value.to_s
      code if code.match?(/\A[a-z0-9_.-]{1,64}\z/i)
    end
  end
end
