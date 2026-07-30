module Quickbooks
  module Oauth
    class ExchangeAuthorizationCode
      MAXIMUM_CODE_LENGTH = 512

      def initialize(
        configuration: Configuration.new,
        connection_store: SandboxConnectionStore.configured,
        token_client: nil
      )
        @connection_store = connection_store
        @token_client = token_client || TokenClient.new(configuration:)
      end

      def call(code:, realm_id:)
        validate_callback_values!(code:, realm_id:)
        connection_store.create(realm_id:, token_set: token_client.exchange(code:))
      end

      private

      attr_reader :connection_store, :token_client

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
