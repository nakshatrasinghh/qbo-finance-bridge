module Quickbooks
  module CompanyInfo
    class Fetch
      def initialize(connection:, client: nil)
        @connection = connection
        @client = client || Client.new(connection: connection)
      end

      def call
        response = client.get("companyinfo/#{connection.realm_id}")
        payload = response["CompanyInfo"]
        details = Details.from_payload(payload) if payload.is_a?(Hash)
        return details if details&.id.present?

        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected CompanyInfo data.",
                code: "quickbooks_company_info_unexpected",
                http_status: :bad_gateway
              )
      end

      private

      attr_reader :client, :connection
    end
  end
end
