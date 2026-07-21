module Quickbooks
  module Customers
    class Create
      NAME_PATTERN = /\A[^:\t\r\n]+\z/
      EMAIL_PATTERN = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/
      PHONE_PATTERN = /\A[0-9+().\- ]+\z/

      def initialize(
        connection:,
        display_name: nil,
        company_name: nil,
        email: nil,
        phone: nil,
        request_id:,
        client: nil
      )
        @connection = connection
        @display_name = display_name.to_s.strip
        @company_name = company_name.to_s.strip
        @email = email.to_s.strip
        @phone = phone.to_s.strip
        @request_id = request_id
        @client = client || Client.new(connection: connection)
        @post_attempted = false
      end

      def call
        validate_input!
        validate_unique_name!

        @post_attempted = true
        response = client.post("customer", json: payload, params: { requestid: request_id })
        @quickbooks_entity_id = response.dig("Customer", "Id").to_s
        if quickbooks_entity_id.blank?
          raise_unexpected!("QuickBooks did not return the created Customer ID.")
        end

        readback(quickbooks_entity_id)
      end

      attr_reader :quickbooks_entity_id

      def post_attempted?
        @post_attempted
      end

      private

      attr_reader :client, :company_name, :connection, :display_name, :email, :phone, :request_id

      def validate_input!
        unless display_name.length.between?(1, 100) && display_name.match?(NAME_PATTERN)
          raise_input!(
            "Customer display name must be 1 to 100 characters without colon, tab, or newline."
          )
        end
        if company_name.present? &&
             (company_name.length > 100 || !company_name.match?(NAME_PATTERN))
          raise_input!(
            "Company name must be at most 100 characters without colon, tab, or newline."
          )
        end
        if email.present? && (email.length > 100 || !email.match?(EMAIL_PATTERN))
          raise_input!("Email must be a valid address of at most 100 characters.")
        end
        if phone.present? && (phone.length > 30 || !phone.match?(PHONE_PATTERN))
          raise_input!("Phone must use at most 30 phone-number characters.")
        end
      end

      def validate_unique_name!
        duplicate =
          Query
            .new(connection: connection, client: client)
            .call
            .any? { |customer| customer.display_name.casecmp?(display_name) }
        if duplicate
          raise_input!("An active QuickBooks Customer with this display name already exists.")
        end
      end

      def payload
        result = { "DisplayName" => display_name }
        result["CompanyName"] = company_name if company_name.present?
        result["PrimaryEmailAddr"] = { "Address" => email } if email.present?
        result["PrimaryPhone"] = { "FreeFormNumber" => phone } if phone.present?
        result
      end

      def readback(id)
        response = client.get("customer/#{id}")
        raw = response["Customer"]
        unless raw.is_a?(Hash)
          raise_unexpected!("QuickBooks returned invalid Customer readback data.")
        end

        customer = Details.from_payload(raw)
        valid =
          customer.id == id && customer.display_name == display_name &&
            (company_name.blank? || customer.company_name == company_name) &&
            (email.blank? || customer.email&.casecmp?(email)) &&
            (phone.blank? || customer.phone == phone)
        unless valid
          raise_unexpected!("QuickBooks Customer readback did not match the submitted record.")
        end

        customer
      end

      def raise_input!(message)
        raise Error::Validation.new(
                message,
                code: "quickbooks_customer_input_invalid",
                http_status: :unprocessable_entity
              )
      end

      def raise_unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_customer_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
