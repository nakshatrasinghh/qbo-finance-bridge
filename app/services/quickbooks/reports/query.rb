module Quickbooks
  module Reports
    class Query
      ENDPOINTS = {
        profit_and_loss: "reports/ProfitAndLoss",
        balance_sheet: "reports/BalanceSheet",
        cash_flow: "reports/CashFlow",
        general_ledger: "reports/GeneralLedger",
        trial_balance: "reports/TrialBalance"
      }.freeze

      def initialize(connection:, parameters:, client: nil)
        @client = client || Client.new(connection: connection)
        @parameters = parameters
      end

      def call
        endpoint = ENDPOINTS.fetch(parameters.report_type)
        response = client.get(endpoint, params: parameters.quickbooks_params)

        Details.from_payload(report_type: parameters.report_type, payload: response)
      rescue KeyError
        raise Error::Configuration.new(
                "QuickBooks report configuration is invalid.",
                code: "quickbooks_report_configuration_invalid",
                http_status: :internal_server_error
              )
      end

      private

      attr_reader :client, :parameters
    end
  end
end
