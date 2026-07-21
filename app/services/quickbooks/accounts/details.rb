module Quickbooks
  module Accounts
    class Details < Data.define(
      :id,
      :name,
      :fully_qualified_name,
      :number,
      :account_type,
      :account_subtype,
      :classification,
      :active
    )
      def self.from_payload(payload)
        new(
          id: payload["Id"].to_s,
          name: payload["Name"].to_s,
          fully_qualified_name: payload["FullyQualifiedName"].presence,
          number: payload["AcctNum"].presence,
          account_type: payload["AccountType"].to_s,
          account_subtype: payload["AccountSubType"].presence,
          classification: payload["Classification"].presence,
          active: payload["Active"]
        )
      end

      def display_name
        if number.present?
          "#{number} — #{fully_qualified_name || name}"
        else
          fully_qualified_name || name
        end
      end
    end
  end
end
