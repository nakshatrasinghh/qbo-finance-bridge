module Quickbooks
  module Vendors
    class Serializer
      def self.call(vendor)
        {
          id: vendor.id,
          display_name: vendor.display_name,
          company_name: vendor.company_name,
          email: vendor.email,
          phone: vendor.phone,
          balance: vendor.balance.to_s("F"),
          active: vendor.active
        }
      end
    end
  end
end
