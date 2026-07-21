module Quickbooks
  module Customers
    class Serializer
      def self.call(customer)
        {
          id: customer.id,
          display_name: customer.display_name,
          company_name: customer.company_name,
          email: customer.email,
          phone: customer.phone,
          balance: customer.balance.to_s("F"),
          active: customer.active
        }
      end
    end
  end
end
