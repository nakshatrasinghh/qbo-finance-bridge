require "test_helper"

class QuickbooksConnectionsShowViewTest < ActionView::TestCase
  test "does not render CompanyInfo readback data" do
    html =
      ApplicationController.render(
        template: "quickbooks/connections/show",
        assigns: {
          connection: sandbox_connection,
          company_info:
            Quickbooks::CompanyInfo::Details.new(
              id: "company-info-id-sentinel",
              company_name: "company-name-sentinel",
              legal_name: "legal-name-sentinel",
              country: "country-sentinel",
              fiscal_year_start_month: "fiscal-month-sentinel",
              subscription_status: "subscription-status-sentinel",
              default_time_zone: "time-zone-sentinel"
            )
        },
        layout: false
      )

    refute_includes html, "CompanyInfo readback"
    refute_includes html, "company-info-id-sentinel"
    refute_includes html, "company-name-sentinel"
    refute_includes html, "legal-name-sentinel"
    refute_includes html, "country-sentinel"
    refute_includes html, "fiscal-month-sentinel"
    refute_includes html, "subscription-status-sentinel"
    refute_includes html, "time-zone-sentinel"
    refute_includes html, "Fiscal year starts"
    refute_includes html, "Subscription status"
    refute_includes html, "Default time zone"
    refute_includes html, "The CompanyInfo read succeeded"
    assert_includes html, "GET/POST dashboards"
  end

  test "does not render the process-local connection status" do
    html =
      ApplicationController.render(
        template: "quickbooks/connections/show",
        assigns: {
          connection: sandbox_connection
        },
        layout: false
      )

    refute_includes html, "Connection status"
    refute_includes html, "Connected in this Rails process"
    assert_includes html, "GET/POST dashboards"
  end

  test "renders a generic connection verification error" do
    html =
      ApplicationController.render(
        template: "quickbooks/connections/show",
        assigns: {
          connection: sandbox_connection,
          quickbooks_error:
            Quickbooks::Error::UnexpectedResponse.new(
              "upstream verification message",
              code: "verification_error_code",
              http_status: :bad_gateway
            )
        },
        layout: false
      )
    document = Rails::Dom::Testing.html_document_fragment.parse(html)
    alert = document.at_css("[role='alert']")

    assert alert, "Expected a connection verification alert"
    assert_includes alert.text, "QuickBooks connection verification failed"
    assert_includes alert.text, "upstream verification message"
    assert_includes alert.text, "verification_error_code"
    refute_includes alert.text, "CompanyInfo could not be read"
  end

  test "renders all GET/POST dashboards under one heading" do
    html =
      ApplicationController.render(
        template: "quickbooks/connections/show",
        assigns: {
          connection: sandbox_connection
        },
        layout: false
      )
    document = Rails::Dom::Testing.html_document_fragment.parse(html)
    links = document.css("a").to_h { |anchor| [anchor.text.strip, anchor["href"]] }
    routes = Rails.application.routes.url_helpers
    navigation_headings =
      document
        .css("h2")
        .filter_map do |heading|
          text = heading.text.strip
          text if text.include?("GET/POST")
        end
    dashboard_list =
      document.at_xpath(
        ".//h2[normalize-space()='GET/POST dashboards']/following-sibling::*[1][self::ul]"
      )

    assert_equal ["GET/POST dashboards"], navigation_headings
    assert dashboard_list, "Expected one dashboard list immediately after the GET/POST heading"
    assert_equal [
                   "Open financial records dashboard",
                   "Open sales and payables dashboard",
                   "Open workforce, tax, and inventory operations",
                   "Open Swagger GET/POST dashboard"
                 ],
                 dashboard_list.xpath("./li/a").map { |anchor| anchor.text.strip }
    assert_equal routes.quickbooks_connection_journal_entries_path(sandbox_connection.id),
                 links["Open financial records dashboard"]
    assert_equal routes.quickbooks_connection_transactions_path(sandbox_connection.id),
                 links["Open sales and payables dashboard"]
    assert_equal routes.quickbooks_connection_operations_path(sandbox_connection.id),
                 links["Open workforce, tax, and inventory operations"]
    assert_equal routes.api_docs_path, links["Open Swagger GET/POST dashboard"]
    assert html.include?("Swagger calls Rails, and Rails calls QuickBooks sandbox."),
           "Expected the existing Swagger explanation"
  end

  private

  def sandbox_connection
    @sandbox_connection ||=
      Quickbooks::SandboxConnection.new(
        id: "123e4567-e89b-42d3-a456-426614174000",
        realm_id: "123456789",
        access_token: "test-access-token",
        refresh_token: "test-refresh-token",
        access_token_expires_at: 1.hour.from_now,
        refresh_token_expires_at: 100.days.from_now
      )
  end
end
