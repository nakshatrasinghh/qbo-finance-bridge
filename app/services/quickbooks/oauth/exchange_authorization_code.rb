module Quickbooks
  module Oauth
    class ExchangeAuthorizationCode
      MAXIMUM_CODE_LENGTH = 512

      def initialize(configuration: Configuration.new, token_client: nil)
        @configuration = configuration
        @token_client = token_client || TokenClient.new(configuration: configuration)
      end

      def call(code:, realm_id:)
        validate_callback_values!(code:, realm_id:)
        token_set = token_client.exchange(code: code)
        connection =
          QuickbooksConnection.find_or_initialize_by(
            environment: configuration.environment,
            realm_id: realm_id
          )
        connection.store_authorization!(
          token_set: token_set,
          scopes: Configuration::ACCOUNTING_SCOPE
        )
        connection
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::StaleObjectError
        raise Error::Conflict.new(
                "This QuickBooks company was connected concurrently. Start the connection again.",
                code: "quickbooks_connection_conflict",
                http_status: :conflict
              )
      end

      private

      attr_reader :configuration, :token_client

      def validate_callback_values!(code:, realm_id:)
        valid_code = code.present? && code.bytesize <= MAXIMUM_CODE_LENGTH
        valid_realm = realm_id.to_s.match?(/\A\d{1,255}\z/)
        return if valid_code && valid_realm

        raise Error::Authentication.new(
                "QuickBooks returned an invalid authorization callback.",
                code: "quickbooks_oauth_callback_invalid",
                http_status: :unauthorized
              )
      end
    end
  end
end
