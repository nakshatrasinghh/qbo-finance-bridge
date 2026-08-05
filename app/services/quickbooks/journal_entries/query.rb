module Quickbooks
  module JournalEntries
    class Query
      def initialize(connection:, parameters: ReadParameters.build, client: nil)
        @client = client || Client.new(connection: connection)
        @parameters = parameters
      end

      def call
        response = client.get("query", params: { query: query_statement })
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response["JournalEntry"]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array)

        entries =
          payloads.map do |payload|
            raise_unexpected! unless payload.is_a?(Hash) && payload["Line"].is_a?(Array)

            entry = Details.from_payload(payload)
            valid =
              entry.id.present? && entry.txn_date.match?(/\A\d{4}-\d{2}-\d{2}\z/) &&
                entry.lines.present?
            raise_unexpected! unless valid

            entry
          end

        has_more = entries.length > parameters.per_page
        ReadPage.new(
          records: entries.first(parameters.per_page).freeze,
          parameters: parameters,
          has_more: has_more
        )
      end

      private

      attr_reader :client, :parameters

      def query_statement
        parts = ["SELECT * FROM JournalEntry"]
        filters = []
        filters << "TxnDate >= '#{parameters.txn_date_from.iso8601}'" if parameters.txn_date_from
        filters << "TxnDate <= '#{parameters.txn_date_to.iso8601}'" if parameters.txn_date_to
        parts << "WHERE #{filters.join(" AND ")}" if filters.present?
        parts << "ORDERBY TxnDate DESC, Id DESC"
        parts << "STARTPOSITION #{parameters.start_position} MAXRESULTS #{parameters.query_limit}"
        parts.join(" ")
      end

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected JournalEntry data.",
                code: "quickbooks_journal_entries_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
