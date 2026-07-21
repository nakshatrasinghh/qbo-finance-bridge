module Quickbooks
  module Employees
    class Query
      MAX_RESULTS = 1_000

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection: connection)
      end

      def call
        response =
          client.get(
            "query",
            params: {
              query: "SELECT * FROM Employee WHERE Active = true MAXRESULTS #{MAX_RESULTS}"
            }
          )
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["Employee"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)

            employee = Details.from_payload(payload)
            valid =
              employee.id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT) &&
                employee.display_name.present? && employee.active == true
            raise_unexpected! unless valid

            employee
          end
          .sort_by { |employee| employee.display_name.downcase }
          .freeze
      end

      private

      attr_reader :client

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected Employee data.",
                code: "quickbooks_employees_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
