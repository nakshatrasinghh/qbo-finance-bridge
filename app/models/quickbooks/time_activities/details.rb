module Quickbooks
  module TimeActivities
    class Details < Data.define(
      :id,
      :txn_date,
      :employee_id,
      :employee_name,
      :hours,
      :minutes,
      :description
    )
      def self.from_payload(payload)
        employee_ref = payload["EmployeeRef"]

        new(
          id: payload["Id"].to_s,
          txn_date: payload["TxnDate"].to_s,
          employee_id: employee_ref.is_a?(Hash) ? employee_ref["value"].to_s : "",
          employee_name: employee_ref.is_a?(Hash) ? employee_ref["name"].presence : nil,
          hours: Integer(payload["Hours"] || 0, exception: false),
          minutes: Integer(payload["Minutes"] || 0, exception: false),
          description: payload["Description"].presence
        )
      end
    end
  end
end
