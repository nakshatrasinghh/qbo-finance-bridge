require "test_helper"

class QuickbooksConnectionsControllerTest < ActionController::TestCase
  tests Quickbooks::ConnectionsController

  class SuccessfulExchange
    attr_reader :code, :realm_id

    def initialize(connection)
      @connection = connection
    end

    def call(code:, realm_id:)
      @code = code
      @realm_id = realm_id
      @connection
    end
  end

  setup do
    @store = Quickbooks::SandboxConnectionStore.configured
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

  teardown { @store.evict(@connection.id) if @store.fetch(@connection.id) }

  test "successful OAuth callback rotates the session before storing the connection" do
    state = "valid-oauth-state"
    exchange = SuccessfulExchange.new(@connection)
    callback_session = {
      Quickbooks::ConnectionsController::OAUTH_STATE_SESSION_KEY => {
        "value" => state,
        "expires_at" => 1.minute.from_now.to_i
      },
      "pre_oauth_marker" => "stale"
    }

    with_exchange(exchange) do
      get :callback,
          params: {
            state: state,
            code: "authorization-code",
            realmId: @connection.realm_id
          },
          session: callback_session
    end

    assert_response :redirect
    assert_redirected_to quickbooks_connection_path(@connection.id)
    assert_nil session["pre_oauth_marker"]
    assert_nil session[Quickbooks::ConnectionsController::OAUTH_STATE_SESSION_KEY]
    assert_equal @connection.id, session[Quickbooks::BaseController::CONNECTION_SESSION_KEY]
    assert_equal "authorization-code", exchange.code
    assert_equal @connection.realm_id, exchange.realm_id
  end

  private

  def with_exchange(replacement)
    exchange_class = Quickbooks::Oauth::ExchangeAuthorizationCode
    original = exchange_class.method(:new)
    exchange_class.define_singleton_method(:new) { |**| replacement }
    yield
  ensure
    exchange_class.define_singleton_method(:new, original)
  end
end
