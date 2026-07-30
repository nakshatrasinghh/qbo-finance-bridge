require "test_helper"
require "uri"

class QuickbooksConnectionScopingTest < ActionDispatch::IntegrationTest
  RECONNECT_MESSAGE =
    "The QuickBooks sandbox connection is missing or expired. Reconnect QuickBooks."

  test "scoped controllers use one QuickBooks connection callback" do
    concern = "Quickbooks::ConnectionScoped".safe_constantize

    assert concern, "Expected Quickbooks::ConnectionScoped to be defined"
    scoped_controllers.each { assert_includes _1.ancestors, concern }
  end

  test "connection list and OAuth actions remain unscoped" do
    get quickbooks_connections_url
    assert_response :success

    get connect_quickbooks_connections_url
    assert_response :redirect
    assert_equal URI(Quickbooks::Configuration::AUTHORIZATION_URL).host, URI(response.location).host

    get callback_quickbooks_connections_url,
        params: {
          state: "invalid",
          code: "test-code",
          realmId: "123456789"
        }
    assert_response :see_other
    assert_redirected_to quickbooks_connections_url
  end

  test "API reconnect response remains normalized and private" do
    get api_v1_quickbooks_connection_accounts_url(SecureRandom.uuid), as: :json

    assert_response :unauthorized
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal(
      { "error" => { "code" => "quickbooks_reconnect_required", "message" => RECONNECT_MESSAGE } },
      response.parsed_body
    )
  end

  private

  def scoped_controllers
    [
      Api::V1::Quickbooks::BaseController,
      Quickbooks::ConnectionsController,
      Quickbooks::JournalEntriesController,
      Quickbooks::OperationsController,
      Quickbooks::TransactionsController
    ]
  end
end
