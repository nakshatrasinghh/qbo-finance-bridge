module Quickbooks
  module TaxCodes
    class Query
      MAX_RESULTS = 1_000

      def initialize(connection:, client: nil)
        @client = client || Client.new(connection: connection)
      end

      def call
        Details::Catalog.new(
          codes:
            unique_records(query_entity("TaxCode").map { |payload| code_from(payload) })
              .sort_by { |code| code.name.downcase }
              .freeze,
          rates:
            unique_records(query_entity("TaxRate").map { |payload| rate_from(payload) })
              .sort_by { |rate| rate.name.downcase }
              .freeze,
          agencies:
            unique_records(query_entity("TaxAgency").map { |payload| agency_from(payload) })
              .sort_by { |agency| agency.display_name.downcase }
              .freeze
        )
      end

      private

      attr_reader :client

      def query_entity(entity)
        response =
          client.get(
            "query",
            params: {
              query: "SELECT * FROM #{entity} MAXRESULTS #{MAX_RESULTS}"
            }
          )
        query_response = response["QueryResponse"]
        raise_unexpected! unless query_response.is_a?(Hash)

        payloads = query_response[entity]
        payloads = [] if payloads.nil?
        raise_unexpected! unless payloads.is_a?(Array) && payloads.all?(Hash)

        payloads
      end

      def code_from(payload)
        code = Details.code_from_payload(payload)
        raise_unexpected! unless valid_id?(code.id) && code.name.present?

        code
      end

      def rate_from(payload)
        rate = Details.rate_from_payload(payload)
        valid =
          valid_id?(rate.id) && rate.name.present? && rate.rate_value &&
            rate.rate_value.between?(0, 100)
        raise_unexpected! unless valid

        rate
      end

      def agency_from(payload)
        agency = Details.agency_from_payload(payload)
        raise_unexpected! unless valid_id?(agency.id) && agency.display_name.present?

        agency
      end

      def valid_id?(value)
        value.match?(QuickbooksSyncOperation::ENTITY_ID_FORMAT)
      end

      def unique_records(records)
        records
          .each_with_object({}) do |record, indexed|
            existing = indexed[record.id]
            raise_unexpected! if existing && existing != record

            indexed[record.id] ||= record
          end
          .values
      end

      def raise_unexpected!
        raise Error::UnexpectedResponse.new(
                "QuickBooks returned unexpected tax configuration data.",
                code: "quickbooks_tax_codes_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
