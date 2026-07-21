module Quickbooks
  module TaxCodes
    class Serializer
      def self.code(code)
        {
          id: code.id,
          name: code.name,
          description: code.description,
          taxable: code.taxable,
          active: code.active,
          sales_rate_ids: code.sales_rate_ids,
          purchase_rate_ids: code.purchase_rate_ids
        }
      end

      def self.rate(rate)
        {
          id: rate.id,
          name: rate.name,
          description: rate.description,
          rate_value: rate.rate_value.to_s("F"),
          agency_id: rate.agency_id,
          agency_name: rate.agency_name,
          active: rate.active
        }
      end

      def self.agency(agency)
        {
          id: agency.id,
          display_name: agency.display_name,
          tracks_sales: agency.tracks_sales,
          tracks_purchases: agency.tracks_purchases
        }
      end

      def self.catalog(catalog)
        {
          tax_codes: catalog.codes.map { |code| self.code(code) },
          tax_rates: catalog.rates.map { |rate| self.rate(rate) },
          tax_agencies: catalog.agencies.map { |agency| self.agency(agency) }
        }
      end
    end
  end
end
