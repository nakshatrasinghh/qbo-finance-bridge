module Quickbooks
  module TaxCodes
    class Details
      Code =
        Data.define(
          :id,
          :name,
          :description,
          :taxable,
          :active,
          :sales_rate_ids,
          :purchase_rate_ids
        )
      Rate = Data.define(:id, :name, :description, :rate_value, :agency_id, :agency_name, :active)
      Agency = Data.define(:id, :display_name, :tracks_sales, :tracks_purchases)
      Catalog = Data.define(:codes, :rates, :agencies)

      def self.code_from_payload(payload)
        Code.new(
          id: payload["Id"].to_s,
          name: payload["Name"].to_s,
          description: payload["Description"].presence,
          taxable: payload["Taxable"] == true,
          active: payload["Active"] != false,
          sales_rate_ids: rate_ids(payload["SalesTaxRateList"]),
          purchase_rate_ids: rate_ids(payload["PurchaseTaxRateList"])
        )
      end

      def self.rate_from_payload(payload)
        agency_ref = payload["AgencyRef"]

        Rate.new(
          id: payload["Id"].to_s,
          name: payload["Name"].to_s,
          description: payload["Description"].presence,
          rate_value: BigDecimal(payload["RateValue"].to_s, exception: false),
          agency_id: agency_ref.is_a?(Hash) ? agency_ref["value"].to_s : "",
          agency_name: agency_ref.is_a?(Hash) ? agency_ref["name"].presence : nil,
          active: payload["Active"] != false
        )
      end

      def self.agency_from_payload(payload)
        Agency.new(
          id: payload["Id"].to_s,
          display_name: payload["DisplayName"].to_s,
          tracks_sales: payload["TaxTrackedOnSales"] == true,
          tracks_purchases: payload["TaxTrackedOnPurchases"] == true
        )
      end

      def self.rate_ids(rate_list)
        details = rate_list.is_a?(Hash) ? rate_list["TaxRateDetail"] : nil
        Array(details)
          .filter_map do |detail|
            reference = detail["TaxRateRef"] if detail.is_a?(Hash)
            reference["value"].to_s.presence if reference.is_a?(Hash)
          end
          .freeze
      end

      private_class_method :rate_ids
    end
  end
end
