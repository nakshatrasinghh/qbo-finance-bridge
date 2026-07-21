require "set"

module Quickbooks
  module Accounts
    class Query
      PAGE_SIZE = 1_000
      MAX_PAGES = 100

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection: connection)
      end

      def call
        accounts = []
        seen_ids = Set.new
        start_position = 1

        MAX_PAGES.times do
          page = fetch_page(start_position: start_position)
          append_unique_accounts!(accounts, seen_ids, page)
          if page.length < PAGE_SIZE
            return accounts.sort_by { |account| account.display_name.downcase }.freeze
          end

          start_position += PAGE_SIZE
        end

        raise_unexpected!("QuickBooks Account pagination exceeded the safety limit.")
      end

      private

      attr_reader :client

      def fetch_page(start_position:)
        statement =
          "SELECT * FROM Account WHERE Active = true " \
            "STARTPOSITION #{start_position} MAXRESULTS #{PAGE_SIZE}"
        response = client.get("query", params: { query: statement })
        query_response = response["QueryResponse"]
        unless query_response.is_a?(Hash)
          raise_unexpected!("QuickBooks returned unexpected Account query data.")
        end

        payloads = query_response["Account"]
        return [] if payloads.nil?
        unless payloads.is_a?(Array)
          raise_unexpected!("QuickBooks returned an invalid Account collection.")
        end

        payloads.map do |payload|
          unless payload.is_a?(Hash)
            raise_unexpected!("QuickBooks returned an invalid Account record.")
          end

          account = Details.from_payload(payload)
          valid =
            account.id.present? && account.name.present? && account.account_type.present? &&
              account.active == true
          raise_unexpected!("QuickBooks returned an incomplete active Account record.") unless valid

          account
        end
      end

      def append_unique_accounts!(accounts, seen_ids, page)
        page.each do |account|
          if seen_ids.include?(account.id)
            raise_unexpected!("QuickBooks returned a duplicate Account ID across pages.")
          end

          seen_ids.add(account.id)
          accounts << account
        end
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_accounts_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
