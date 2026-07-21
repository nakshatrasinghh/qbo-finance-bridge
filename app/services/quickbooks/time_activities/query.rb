module Quickbooks
  module TimeActivities
    class Query
      MAX_RESULTS = 100

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection: connection)
      end

      def call
        response =
          client.get(
            "query",
            params: {
              query: "SELECT * FROM TimeActivity ORDERBY TxnDate DESC MAXRESULTS #{MAX_RESULTS}"
            }
          )
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["TimeActivity"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        payloads
          .map do |payload|
            raise_unexpected! unless payload.is_a?(Hash)

            activity = Details.from_payload(payload)
            valid =
              activity.id.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT) &&
                activity.txn_date.match?(/\A\d{4}-\d{2}-\d{2}\z/) &&
                activity.employee_id.present? && activity.hours.is_a?(Integer) &&
                activity.minutes.is_a?(Integer)
            raise_unexpected! unless valid

            activity
          end
          .freeze
      end

      private

      attr_reader :client

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected TimeActivity data.",
                code: "quickbooks_time_activities_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
