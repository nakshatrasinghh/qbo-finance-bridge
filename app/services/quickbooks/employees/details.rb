module Quickbooks
  module Employees
    class Details < Data.define(
      :id,
      :display_name,
      :given_name,
      :family_name,
      :email,
      :phone,
      :active
    )
      def self.from_payload(payload)
        email = payload["PrimaryEmailAddr"]
        phone = payload["PrimaryPhone"]

        new(
          id: payload["Id"].to_s,
          display_name: payload["DisplayName"].to_s,
          given_name: payload["GivenName"].to_s,
          family_name: payload["FamilyName"].to_s,
          email: email.is_a?(Hash) ? email["Address"].presence : nil,
          phone: phone.is_a?(Hash) ? phone["FreeFormNumber"].presence : nil,
          active: payload["Active"]
        )
      end
    end
  end
end
