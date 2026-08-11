module Quickbooks
  class SandboxConnection
    ID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
    REALM_ID_FORMAT = /\A\d{1,255}\z/
    ENVIRONMENT = "sandbox"

    def initialize(
      id:,
      realm_id:,
      access_token:,
      refresh_token:,
      access_token_expires_at:,
      refresh_token_expires_at: nil,
      environment: ENVIRONMENT,
      created_at: Time.current,
      updated_at: created_at,
      last_refreshed_at: nil
    )
      validate!(
        id:,
        realm_id:,
        access_token:,
        refresh_token:,
        access_token_expires_at:,
        refresh_token_expires_at:,
        environment:,
        created_at:,
        updated_at:,
        last_refreshed_at:
      )
      @attributes = {
        id: immutable_string(id),
        realm_id: immutable_string(realm_id),
        access_token: immutable_string(access_token),
        refresh_token: immutable_string(refresh_token),
        access_token_expires_at: immutable_time(access_token_expires_at),
        refresh_token_expires_at: immutable_optional_time(refresh_token_expires_at),
        environment: immutable_string(environment),
        created_at: immutable_time(created_at),
        updated_at: immutable_time(updated_at),
        last_refreshed_at: immutable_optional_time(last_refreshed_at)
      }.freeze
      freeze
    end

    def id = attributes.fetch(:id)
    def realm_id = attributes.fetch(:realm_id)
    def access_token = attributes.fetch(:access_token)
    def refresh_token = attributes.fetch(:refresh_token)
    def access_token_expires_at = attributes.fetch(:access_token_expires_at)
    def refresh_token_expires_at = attributes.fetch(:refresh_token_expires_at)
    def environment = attributes.fetch(:environment)
    def created_at = attributes.fetch(:created_at)
    def updated_at = attributes.fetch(:updated_at)
    def last_refreshed_at = attributes.fetch(:last_refreshed_at)

    def access_token_expired?(at: Time.current, skew: 1.minute)
      access_token_expires_at <= at + skew
    end

    def with_refreshed_tokens(token_set:, refreshed_at: Time.current)
      self.class.new(
        id:,
        realm_id:,
        access_token: token_set.access_token,
        refresh_token: token_set.refresh_token,
        access_token_expires_at: token_set.access_token_expires_at,
        refresh_token_expires_at: token_set.refresh_token_expires_at || refresh_token_expires_at,
        environment:,
        created_at:,
        updated_at: refreshed_at,
        last_refreshed_at: refreshed_at
      )
    end

    def inspect
      "#<#{self.class.name} id=#{id.inspect} realm_id=#{realm_id.inspect} " \
        "environment=#{environment.inspect} access_token=[FILTERED] refresh_token=[FILTERED]>"
    end

    def to_s = inspect

    def pretty_print(printer)
      printer.text(inspect)
    end

    def as_json(*)
      raise TypeError, "#{self.class.name} contains secret token material and cannot be serialized."
    end

    def to_json(*)
      raise TypeError, "#{self.class.name} contains secret token material and cannot be serialized."
    end

    private

    attr_reader :attributes

    def validate!(**values)
      require_format!(values.fetch(:id), ID_FORMAT, "connection ID")
      require_format!(values.fetch(:realm_id), REALM_ID_FORMAT, "realm ID")
      require_string!(values.fetch(:access_token), "access token")
      require_string!(values.fetch(:refresh_token), "refresh token")
      require_time!(values.fetch(:access_token_expires_at), "access token expiry")
      require_optional_time!(values.fetch(:refresh_token_expires_at), "refresh token expiry")
      require_time!(values.fetch(:created_at), "creation time")
      require_time!(values.fetch(:updated_at), "update time")
      require_optional_time!(values.fetch(:last_refreshed_at), "last refreshed time")
      return if values.fetch(:environment) == ENVIRONMENT

      raise Error::InvalidSandboxConfiguration.new(
              "QuickBooks connections must use the sandbox environment.",
              code: "quickbooks_environment_not_sandbox",
              http_status: :service_unavailable
            )
    end

    def require_format!(value, format, label)
      return if value.is_a?(String) && value.match?(format)

      raise ArgumentError, "#{label} is invalid"
    end

    def require_string!(value, label)
      return if value.is_a?(String) && value.present?

      raise ArgumentError, "#{label} is required"
    end

    def require_time!(value, label)
      return if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      raise ArgumentError, "#{label} is invalid"
    end

    def require_optional_time!(value, label)
      require_time!(value, label) if value
    end

    def immutable_string(value)
      value.dup.freeze
    end

    def immutable_time(value)
      value.dup.freeze
    end

    def immutable_optional_time(value)
      immutable_time(value) if value
    end
  end
end
