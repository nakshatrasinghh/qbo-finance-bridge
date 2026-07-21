module Quickbooks
  module Oauth
    class Disconnect
      def initialize(connection:, configuration: Configuration.new, token_client: nil)
        @connection = connection
        @token_client = token_client || TokenClient.new(configuration: configuration)
      end

      def call
        return connection if connection.disconnected?

        token_client.revoke(token: connection.refresh_token)
        connection.mark_disconnected!
        connection
      end

      private

      attr_reader :connection, :token_client
    end
  end
end
