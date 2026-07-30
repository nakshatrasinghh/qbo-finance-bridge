require "test_helper"

class QuickbooksConnectionControllerTestCase < ActionController::TestCase
  RECONNECT_MESSAGE =
    "The QuickBooks sandbox connection is missing or expired. Reconnect QuickBooks."
  SESSION_KEY = Quickbooks::BaseController::CONNECTION_SESSION_KEY

  setup do
    @connection = connection_store.create(realm_id: "123456789", token_set: sandbox_token_set)
  end

  teardown do
    connection_store.disconnect(@connection.id) {} if connection_store.fetch(@connection.id)
  end

  private

  def owned_session
    { SESSION_KEY => @connection.id }
  end

  def connection_store
    Quickbooks::SandboxConnectionStore.configured
  end

  def sandbox_token_set
    Quickbooks::Oauth::TokenSet.new(
      access_token: "test-access-token",
      refresh_token: "test-refresh-token",
      access_token_expires_at: 1.hour.from_now,
      refresh_token_expires_at: 100.days.from_now
    )
  end
end

class QuickbooksOperationsConnectionScopingTest < QuickbooksConnectionControllerTestCase
  tests Quickbooks::OperationsController

  test "matching session-owned connection loads before the action" do
    get :show, params: { connection_id: @connection.id }, session: owned_session

    assert_response :success
    assert_includes response.body,
                    %(data-employees-url="#{api_v1_quickbooks_connection_employees_path(@connection.id)}")
  end

  test "existing unowned connection is rejected without clearing the owned session" do
    unowned_connection =
      connection_store.create(realm_id: "987654321", token_set: sandbox_token_set)

    get :show, params: { connection_id: unowned_connection.id }, session: owned_session

    assert_response :unauthorized
    assert_equal RECONNECT_MESSAGE, response.body
    assert_equal @connection.id, session[SESSION_KEY]
  ensure
    connection_store.disconnect(unowned_connection.id) {} if unowned_connection
  end

  test "evicted connection clears the stale session" do
    connection_store.disconnect(@connection.id) {}

    get :show, params: { connection_id: @connection.id }, session: owned_session

    assert_response :unauthorized
    assert_equal RECONNECT_MESSAGE, response.body
    assert_nil session[SESSION_KEY]
  end
end

class QuickbooksConnectionsMemberScopingTest < QuickbooksConnectionControllerTestCase
  tests Quickbooks::ConnectionsController

  test "member scope uses the route id instead of a query connection id" do
    forged_id = SecureRandom.uuid
    @request.path_parameters = {
      controller: "quickbooks/connections",
      action: "show",
      id: forged_id
    }
    @request.session[SESSION_KEY] = @connection.id
    @controller.params =
      ActionController::Parameters.new(id: forged_id, connection_id: @connection.id)

    error =
      assert_raises(Quickbooks::Error::ReconnectRequired) do
        @controller.send(:owned_quickbooks_connection_id)
      end

    assert_equal "quickbooks_reconnect_required", error.code
    assert_equal @connection.id, @request.session[SESSION_KEY]
  end

  test "connection member route is scoped by id before QuickBooks access" do
    get :show, params: { id: SecureRandom.uuid }, session: owned_session

    assert_response :unauthorized
    assert_equal RECONNECT_MESSAGE, response.body
    assert_equal @connection.id, session[SESSION_KEY]
  end
end
