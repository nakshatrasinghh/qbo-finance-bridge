module Quickbooks
  module Oauth
    class Disconnect
      def initialize(
        connection_id:,
        configuration: Configuration.new,
        connection_store: SandboxConnectionStore.configured,
        token_client: nil
      )
        @connection_id = connection_id
        @connection_store = connection_store
        @token_client = token_client || TokenClient.new(configuration:)
      end

      def call
        connection_store.disconnect(connection_id) do |connection|
          token_client.revoke(token: connection.refresh_token)
        end
      end

      private

      attr_reader :connection_id, :connection_store, :token_client
    end
  end
end
