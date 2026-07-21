module Quickbooks
  module TimeActivities
    class Serializer
      def self.call(activity)
        {
          id: activity.id,
          txn_date: activity.txn_date,
          employee_id: activity.employee_id,
          employee_name: activity.employee_name,
          hours: activity.hours,
          minutes: activity.minutes,
          description: activity.description
        }
      end
    end
  end
end
