require "test_helper"

class QuickbooksHttpTimeoutConfigurationTest < ActiveSupport::TestCase
  setup do
    @configuration = Quickbooks::Configuration.new
    @store = Quickbooks::SandboxConnectionStore.new
    @connection =
      @store.create(
        realm_id: "123456789",
        token_set:
          Quickbooks::Oauth::TokenSet.new(
            access_token: "test-access-token",
            refresh_token: "test-refresh-token",
            access_token_expires_at: 1.hour.from_now,
            refresh_token_expires_at: 100.days.from_now
          )
      )
  end

  test "QuickBooks API writes use the configured read timeout" do
    client =
      Quickbooks::Client.new(
        connection: @connection,
        configuration: @configuration,
        connection_store: @store
      )

    http = client.instance_variable_get(:@http)

    assert_equal @configuration.read_timeout, http.options.write_timeout
  end

  test "OAuth token and revocation writes use the configured read timeout" do
    client = Quickbooks::Oauth::TokenClient.new(configuration: @configuration)

    %i[@token_http @revocation_http].each do |variable|
      http = client.instance_variable_get(variable)
      assert_equal @configuration.read_timeout, http.options.write_timeout
    end
  end
end
