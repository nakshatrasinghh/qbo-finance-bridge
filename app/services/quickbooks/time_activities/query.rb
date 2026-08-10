module Quickbooks
  module TimeActivities
    class Query
      MAX_RESULTS = 100

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection:)
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
              EntityId.valid?(activity.id) && valid_date?(activity.txn_date) &&
                activity.employee_id.present? && activity.hours.is_a?(Integer) &&
                activity.minutes.is_a?(Integer)
            raise_unexpected! unless valid

            activity
          end
          .freeze
      end

      private

      attr_reader :client

      def valid_date?(value)
        Date.iso8601(value).iso8601 == value
      rescue Date::Error
        false
      end

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
