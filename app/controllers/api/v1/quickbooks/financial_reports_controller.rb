module Api
  module V1
    module Quickbooks
      class FinancialReportsController < BaseController
        def profit_and_loss
          render_report(:profit_and_loss)
        end

        def balance_sheet
          render_report(:balance_sheet)
        end

        def cash_flow
          render_report(:cash_flow)
        end

        def general_ledger
          render_report(:general_ledger)
        end

        def trial_balance
          render_report(:trial_balance)
        end

        private

        def render_report(report_type)
          parameters =
            ::Quickbooks::Reports::Parameters.build(report_type:, attributes: report_parameters)
          report = ::Quickbooks::Reports::Query.new(connection: @connection, parameters:).call

          render json: {
                   report: ::Quickbooks::Reports::Serializer.call(report),
                   filters: parameters.filters
                 }
        end

        def report_parameters
          params
            .permit(:connection_id, :start_date, :end_date, :as_of_date, :accounting_method)
            .slice(:start_date, :end_date, :as_of_date, :accounting_method)
            .to_h
        end
      end
    end
  end
end
