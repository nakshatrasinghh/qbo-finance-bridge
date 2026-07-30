module Quickbooks
  module TimeActivities
    class Create
      INTEGER_PATTERN = /\A\d{1,4}\z/

      def initialize(
        connection:,
        employee_id: nil,
        txn_date: nil,
        hours: nil,
        minutes: nil,
        description: nil,
        client: nil
      )
        @connection = connection
        @employee_id = employee_id.to_s
        @txn_date_input = txn_date.to_s
        @hours_input = hours.to_s.strip
        @minutes_input = minutes.to_s.strip
        @description = description.to_s.strip
        @client = client || Client.new(connection:)
      end

      def call
        validate_input!
        validate_employee!

        response = client.post("timeactivity", json: payload)
        quickbooks_entity_id = response.dig("TimeActivity", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created TimeActivity ID.")
        end

        readback(quickbooks_entity_id)
      end

      private

      attr_reader :client, :connection, :description, :employee_id, :hours, :minutes, :txn_date

      def validate_input!
        @txn_date = Date.iso8601(@txn_date_input)
        raise_input!("Choose a valid transaction date.") unless txn_date.iso8601 == @txn_date_input
        raise_input!("Choose a valid active Employee.") unless EntityId.valid?(employee_id)
        unless @hours_input.match?(INTEGER_PATTERN)
          raise_input!("Hours must be a whole number from 0 to 8760.")
        end
        unless @minutes_input.match?(INTEGER_PATTERN)
          raise_input!("Minutes must be a whole number from 0 to 59.")
        end

        @hours = Integer(@hours_input, 10)
        @minutes = Integer(@minutes_input, 10)
        raise_input!("Hours must be a whole number from 0 to 8760.") unless hours.between?(0, 8_760)
        raise_input!("Minutes must be a whole number from 0 to 59.") unless minutes.between?(0, 59)
        if hours.zero? && minutes.zero?
          raise_input!("A time activity must be longer than zero minutes.")
        end
        if hours == 8_760 && minutes.positive?
          raise_input!("Minutes must be zero when hours is 8760.")
        end
        unless description.length.between?(1, 500)
          raise_input!("Description must be 1 to 500 characters.")
        end
      rescue Date::Error
        raise_input!("Choose a valid transaction date.")
      end

      def validate_employee!
        employee =
          Employees::Query.new(connection:, client:).call.find { |record| record.id == employee_id }
        raise_input!("The selected Employee is not active in QuickBooks.") unless employee
      end

      def payload
        {
          "NameOf" => "Employee",
          "EmployeeRef" => {
            "value" => employee_id
          },
          "TxnDate" => txn_date.iso8601,
          "Hours" => hours,
          "Minutes" => minutes,
          "Description" => description
        }
      end

      def readback(id)
        response = client.get("timeactivity/#{id}")
        activity_payload = response["TimeActivity"]
        unless activity_payload.is_a?(Hash)
          raise_unexpected!("QuickBooks returned invalid TimeActivity readback data.")
        end

        activity = Details.from_payload(activity_payload)
        valid =
          activity.id == id && activity.employee_id == employee_id &&
            activity.txn_date == txn_date.iso8601 && activity.hours == hours &&
            activity.minutes == minutes && activity.description == description
        unless valid
          raise_unexpected!("QuickBooks TimeActivity readback did not match the submitted record.")
        end

        activity
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_time_activity_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_time_activity_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
