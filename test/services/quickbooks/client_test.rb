require "test_helper"

class QuickbooksClientTest < ActiveSupport::TestCase
  class RejectingTokenClient
    def refresh(refresh_token:)
      raise Quickbooks::Error::Authentication.new(
              "QuickBooks authorization failed.",
              code: "invalid_grant",
              http_status: :unauthorized,
              upstream_status: 400
            )
    end
  end

  test "refresh rejection evicts the current connection" do
    store = Quickbooks::SandboxConnectionStore.new
    connection =
      store.create(
        realm_id: "123",
        token_set:
          Quickbooks::Oauth::TokenSet.new(
            access_token: "expired-access",
            refresh_token: "expired-refresh",
            access_token_expires_at: 2.minutes.ago,
            refresh_token_expires_at: 1.day.from_now
          )
      )
    client =
      Quickbooks::Client.new(
        connection:,
        connection_store: store,
        token_client: RejectingTokenClient.new
      )

    error = assert_raises(Quickbooks::Error::ReconnectRequired) { client.get("query") }

    assert_equal "quickbooks_reconnect_required", error.code
    assert_nil store.fetch(connection.id)
    assert_nil store.fetch_current
  end
end
