module Quickbooks
  module Employees
    class Serializer
      def self.call(employee)
        {
          id: employee.id,
          display_name: employee.display_name,
          given_name: employee.given_name,
          family_name: employee.family_name,
          email: employee.email,
          phone: employee.phone,
          active: employee.active
        }
      end
    end
  end
end
