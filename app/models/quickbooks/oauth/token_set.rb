module Quickbooks
  module Oauth
    class TokenSet < Data.define(
      :access_token,
      :refresh_token,
      :access_token_expires_at,
      :refresh_token_expires_at
    )
      def self.from_payload(payload, now: Time.current)
        unless payload.is_a?(Hash)
          raise Error::UnexpectedResponse.new(
                  "QuickBooks returned an invalid token response.",
                  code: "quickbooks_token_response_invalid",
                  http_status: :bad_gateway
                )
        end

        access_token = payload["access_token"].presence
        refresh_token = payload["refresh_token"].presence
        access_lifetime = positive_integer(payload["expires_in"])
        refresh_lifetime = positive_integer(payload["x_refresh_token_expires_in"], required: false)

        unless access_token && refresh_token && access_lifetime
          raise Error::UnexpectedResponse.new(
                  "QuickBooks returned an incomplete token response.",
                  code: "quickbooks_token_response_incomplete",
                  http_status: :bad_gateway
                )
        end

        new(
          access_token:,
          refresh_token:,
          access_token_expires_at: now + access_lifetime,
          refresh_token_expires_at: refresh_lifetime ? now + refresh_lifetime : nil
        )
      end

      def self.positive_integer(value, required: true)
        return unless required || value.present?

        integer = Integer(value, exception: false)
        integer if integer&.positive?
      end
      private_class_method :positive_integer

      def inspect
        "#<#{self.class.name} access_token=[FILTERED] refresh_token=[FILTERED] " \
          "access_token_expires_at=#{access_token_expires_at.inspect} " \
          "refresh_token_expires_at=#{refresh_token_expires_at.inspect}>"
      end

      def to_s = inspect

      def pretty_print(printer)
        printer.text(inspect)
      end

      def to_h
        raise TypeError,
              "#{self.class.name} contains secret token material and cannot be serialized."
      end

      def as_json(*)
        raise TypeError,
              "#{self.class.name} contains secret token material and cannot be serialized."
      end

      def to_json(*)
        raise TypeError,
              "#{self.class.name} contains secret token material and cannot be serialized."
      end
    end
  end
end
