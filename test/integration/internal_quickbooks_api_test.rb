require "test_helper"

class InternalQuickbooksApiTest < ActionDispatch::IntegrationTest
  setup do
    @store = Quickbooks::SandboxConnectionStore.configured
    @connection =
      @store.create(
        realm_id: "123456789",
        token_set:
          Quickbooks::Oauth::TokenSet.new(
            access_token: "internal-access",
            refresh_token: "internal-refresh",
            access_token_expires_at: 1.hour.from_now,
            refresh_token_expires_at: 100.days.from_now
          )
      )
  end

  teardown { @store.evict(@connection.id) if @store.fetch(@connection.id) }

  test "status exposes connection state without connection identity" do
    get "/internal/v1/quickbooks/status", as: :json

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal({ "connection" => { "state" => "connected" } }, response.parsed_body)
    assert_not_includes response.body, @connection.id
    assert_not_includes response.body, @connection.realm_id
  end

  test "disconnected status remains a successful service response" do
    @store.evict(@connection.id)

    get "/internal/v1/quickbooks/status", as: :json

    assert_response :success
    assert_equal({ "connection" => { "state" => "reconnect_required" } }, response.parsed_body)
  end

  test "non-loopback caller cannot reach the internal API" do
    get "/internal/v1/quickbooks/status", env: { "REMOTE_ADDR" => "203.0.113.10" }, as: :json

    assert_response :not_found
  end

  test "finance reads expose GET routes with internal current connection scoping" do
    internal_concern = Quickbooks::InternalConnectionScoped

    expected_read_routes.each do |path, route|
      recognized = Rails.application.routes.recognize_path(path, method: :get)
      assert_equal route, recognized.slice(:controller, :action)

      controller = route.fetch(:controller).camelize.concat("Controller").safe_constantize
      assert controller, "Expected #{route.fetch(:controller)} controller to exist"
      assert_includes controller.ancestors, internal_concern

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(path, method: :post)
      end
    end
  end

  test "successful finance read needs no browser session and returns generation" do
    query = Object.new
    query.define_singleton_method(:call) { [] }

    with_account_query(query) { get "/internal/v1/quickbooks/accounts", as: :json }

    assert_response :success
    assert_equal({ "accounts" => [] }, response.parsed_body)
    assert_equal Digest::SHA256.hexdigest(@connection.id),
                 response.headers["X-QBO-Connection-Generation"]
  end

  test "disconnected finance read returns the stable conflict contract" do
    @store.evict(@connection.id)

    get "/internal/v1/quickbooks/accounts", as: :json

    assert_response :conflict
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal(
      {
        "error" => {
          "code" => "quickbooks_reconnect_required",
          "message" =>
            "The QuickBooks sandbox connection is missing or expired. Reconnect QuickBooks."
        }
      },
      response.parsed_body
    )
  end

  private

  def with_account_query(replacement)
    original = Quickbooks::Accounts::Query.method(:new)
    Quickbooks::Accounts::Query.define_singleton_method(:new) { |**| replacement }
    yield
  ensure
    Quickbooks::Accounts::Query.define_singleton_method(:new, original)
  end

  def expected_read_routes
    {
      "/internal/v1/quickbooks/accounts" => {
        controller: "internal/v1/quickbooks/accounts",
        action: "index"
      },
      "/internal/v1/quickbooks/employees" => {
        controller: "internal/v1/quickbooks/employees",
        action: "index"
      },
      "/internal/v1/quickbooks/time_activities" => {
        controller: "internal/v1/quickbooks/time_activities",
        action: "index"
      },
      "/internal/v1/quickbooks/tax_codes" => {
        controller: "internal/v1/quickbooks/tax_codes",
        action: "index"
      },
      "/internal/v1/quickbooks/inventory_items" => {
        controller: "internal/v1/quickbooks/inventory_items",
        action: "index"
      },
      "/internal/v1/quickbooks/customers" => {
        controller: "internal/v1/quickbooks/customers",
        action: "index"
      },
      "/internal/v1/quickbooks/vendors" => {
        controller: "internal/v1/quickbooks/vendors",
        action: "index"
      },
      "/internal/v1/quickbooks/invoices" => {
        controller: "internal/v1/quickbooks/invoices",
        action: "index"
      },
      "/internal/v1/quickbooks/bills" => {
        controller: "internal/v1/quickbooks/bills",
        action: "index"
      },
      "/internal/v1/quickbooks/customer_payments" => {
        controller: "internal/v1/quickbooks/customer_payments",
        action: "index"
      },
      "/internal/v1/quickbooks/bill_payments" => {
        controller: "internal/v1/quickbooks/bill_payments",
        action: "index"
      },
      "/internal/v1/quickbooks/journal_entries" => {
        controller: "internal/v1/quickbooks/journal_entries",
        action: "index"
      },
      "/internal/v1/quickbooks/reports/profit_and_loss" => {
        controller: "internal/v1/quickbooks/financial_reports",
        action: "profit_and_loss"
      },
      "/internal/v1/quickbooks/reports/balance_sheet" => {
        controller: "internal/v1/quickbooks/financial_reports",
        action: "balance_sheet"
      },
      "/internal/v1/quickbooks/reports/cash_flow" => {
        controller: "internal/v1/quickbooks/financial_reports",
        action: "cash_flow"
      },
      "/internal/v1/quickbooks/reports/general_ledger" => {
        controller: "internal/v1/quickbooks/financial_reports",
        action: "general_ledger"
      },
      "/internal/v1/quickbooks/reports/trial_balance" => {
        controller: "internal/v1/quickbooks/financial_reports",
        action: "trial_balance"
      }
    }
  end
end
