module Quickbooks
  module JournalEntries
    class ReadParameters < Data.define(:txn_date_from, :txn_date_to, :page, :per_page)
      DEFAULT_PAGE = 1
      DEFAULT_PER_PAGE = 50
      MAX_PAGE = 10_000
      MAX_PER_PAGE = 50

      def self.build(attributes = {})
        values = attributes.stringify_keys
        txn_date_from = parse_date(values["txn_date_from"], field: "txn_date_from")
        txn_date_to = parse_date(values["txn_date_to"], field: "txn_date_to")

        if txn_date_from && txn_date_to && txn_date_from > txn_date_to
          invalid!("txn_date_to must be on or after txn_date_from.")
        end

        new(
          txn_date_from: txn_date_from,
          txn_date_to: txn_date_to,
          page:
            parse_integer(values["page"], field: "page", default: DEFAULT_PAGE, maximum: MAX_PAGE),
          per_page:
            parse_integer(
              values["per_page"],
              field: "per_page",
              default: DEFAULT_PER_PAGE,
              maximum: MAX_PER_PAGE
            )
        )
      end

      def start_position
        ((page - 1) * per_page) + 1
      end

      def offset
        (page - 1) * per_page
      end

      def query_limit
        per_page + 1
      end

      def filters
        { txn_date_from: txn_date_from&.iso8601, txn_date_to: txn_date_to&.iso8601 }
      end

      class << self
        private

        def parse_date(value, field:)
          return if value.blank?

          string = value.to_s
          date = Date.iso8601(string)
          return date if date.iso8601 == string

          invalid!("#{field} must be an ISO 8601 date in YYYY-MM-DD format.")
        rescue Date::Error
          invalid!("#{field} must be an ISO 8601 date in YYYY-MM-DD format.")
        end

        def parse_integer(value, field:, default:, maximum:)
          return default if value.blank?

          string = value.to_s
          unless string.match?(/\A[1-9]\d*\z/)
            invalid!("#{field} must be an integer from 1 to #{maximum}.")
          end

          integer = Integer(string, 10)
          return integer if integer <= maximum

          invalid!("#{field} must be an integer from 1 to #{maximum}.")
        end

        def invalid!(message)
          raise Error::Validation.new(
                  message,
                  code: "quickbooks_read_parameters_invalid",
                  http_status: :unprocessable_entity
                )
        end
      end
    end
  end
end
