module Quickbooks
  module TaxCodes
    class Create
      NAME_PATTERN = /\A[^\t\r\n]+\z/
      APPLICABLE_ON = %w[Sales Purchase].freeze

      def initialize(connection:, name: nil, tax_rate_id: nil, applicable_on: nil, client: nil)
        @connection = connection
        @name = name.to_s.strip
        @tax_rate_id = tax_rate_id.to_s
        @applicable_on = applicable_on.to_s
        @client = client || Client.new(connection:)
      end

      def call
        validate_input!
        validate_catalog!

        response = client.post("taxservice/taxcode", json: payload)
        quickbooks_entity_id = response["TaxCodeId"].to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created TaxCode ID.")
        end

        readback(quickbooks_entity_id)
      end

      private

      attr_reader :applicable_on, :client, :connection, :name, :tax_rate_id

      def validate_input!
        unless name.length.between?(1, 100) && name.match?(NAME_PATTERN)
          raise_input!("Tax code name must be 1 to 100 characters without tab or newline.")
        end
        raise_input!("Choose a valid existing TaxRate.") unless EntityId.valid?(tax_rate_id)
        unless APPLICABLE_ON.include?(applicable_on)
          raise_input!("Tax applicability must be Sales or Purchase.")
        end
      end

      def validate_catalog!
        catalog = Query.new(connection:, client:).call
        rate = catalog.rates.find { |record| record.id == tax_rate_id }
        raise_input!("The selected TaxRate is not active in QuickBooks.") unless rate&.active

        agency = catalog.agencies.find { |record| record.id == rate.agency_id }
        supported = applicable_on == "Sales" ? agency&.tracks_sales : agency&.tracks_purchases
        unless supported
          raise_input!(
            "The selected TaxRate is not available for #{applicable_on.downcase} tax in this QuickBooks company."
          )
        end
      end

      def payload
        {
          "TaxCode" => name,
          "TaxRateDetails" => [{ "TaxRateId" => tax_rate_id, "TaxApplicableOn" => applicable_on }]
        }
      end

      def readback(id)
        code = Query.new(connection:, client:).call.codes.find { |record| record.id == id }
        raise_unexpected!("QuickBooks TaxCode readback was not found.") unless code

        matching_rates = applicable_on == "Sales" ? code.sales_rate_ids : code.purchase_rate_ids
        valid = code.name == name && matching_rates.include?(tax_rate_id)
        unless valid
          raise_unexpected!("QuickBooks TaxCode readback did not match the submitted record.")
        end

        code
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_tax_code_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_tax_code_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
