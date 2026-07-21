module Quickbooks
  module Employees
    class Create
      NAME_PATTERN = /\A[^:\t\r\n]+\z/
      EMAIL_PATTERN = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/
      PHONE_PATTERN = /\A[0-9+().\- ]+\z/

      def initialize(
        connection:,
        given_name: nil,
        family_name: nil,
        email: nil,
        phone: nil,
        request_id:,
        client: nil
      )
        @given_name = given_name.to_s.strip
        @family_name = family_name.to_s.strip
        @email = email.to_s.strip
        @phone = phone.to_s.strip
        @request_id = request_id
        @client = client || Client.new(connection: connection)
        @post_attempted = false
      end

      def call
        validate_input!

        @post_attempted = true
        response = client.post("employee", json: payload, params: { requestid: request_id })
        @quickbooks_entity_id = response.dig("Employee", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created Employee ID.")
        end

        readback(quickbooks_entity_id)
      end

      attr_reader :quickbooks_entity_id

      def post_attempted?
        @post_attempted
      end

      private

      attr_reader :client, :email, :family_name, :given_name, :phone, :request_id

      def validate_input!
        validate_name!(given_name, "Given name")
        validate_name!(family_name, "Family name")
        if email.present? && (email.length > 100 || !email.match?(EMAIL_PATTERN))
          raise_input!("Email must be a valid address of at most 100 characters.")
        end
        if phone.present? && (phone.length > 20 || !phone.match?(PHONE_PATTERN))
          raise_input!("Phone must use at most 20 phone-number characters.")
        end
      end

      def validate_name!(value, label)
        return if value.length.between?(1, 100) && value.match?(NAME_PATTERN)

        raise_input!(
          "#{label} must be 1 to 100 characters and cannot contain colon, tab, or newline."
        )
      end

      def payload
        result = { "GivenName" => given_name, "FamilyName" => family_name }
        result["PrimaryEmailAddr"] = { "Address" => email } if email.present?
        result["PrimaryPhone"] = { "FreeFormNumber" => phone } if phone.present?
        result
      end

      def readback(id)
        response = client.get("employee/#{id}")
        employee_payload = response["Employee"]
        unless employee_payload.is_a?(Hash)
          raise_unexpected!("QuickBooks returned invalid Employee readback data.")
        end

        employee = Details.from_payload(employee_payload)
        valid =
          employee.id == id && employee.given_name == given_name &&
            employee.family_name == family_name && (email.blank? || employee.email == email) &&
            (phone.blank? || employee.phone == phone)
        unless valid
          raise_unexpected!("QuickBooks Employee readback did not match the submitted record.")
        end

        employee
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_employee_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_employee_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
