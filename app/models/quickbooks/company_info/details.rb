module Quickbooks
  module CompanyInfo
    class Details < Data.define(
      :id,
      :company_name,
      :legal_name,
      :country,
      :fiscal_year_start_month,
      :subscription_status,
      :default_time_zone
    )
      def self.from_payload(payload)
        new(
          id: payload["Id"].to_s,
          company_name: payload["CompanyName"],
          legal_name: payload["LegalName"],
          country: payload["Country"],
          fiscal_year_start_month: payload["FiscalYearStartMonth"],
          subscription_status: payload["SubscriptionStatus"],
          default_time_zone: payload["DefaultTimeZone"]
        )
      end
    end
  end
end
