module Quickbooks
  module Vendors
    class Details < Data.define(
      :id,
      :display_name,
      :company_name,
      :email,
      :phone,
      :balance,
      :active
    )
      def self.from_payload(payload)
        email = payload["PrimaryEmailAddr"]
        phone = payload["PrimaryPhone"]

        new(
          id: payload["Id"].to_s,
          display_name: payload["DisplayName"].to_s,
          company_name: payload["CompanyName"].presence,
          email: email.is_a?(Hash) ? email["Address"].presence : nil,
          phone: phone.is_a?(Hash) ? phone["FreeFormNumber"].presence : nil,
          balance: BigDecimal(payload["Balance"].to_s, exception: false),
          active: payload["Active"]
        )
      end
    end
  end
end
