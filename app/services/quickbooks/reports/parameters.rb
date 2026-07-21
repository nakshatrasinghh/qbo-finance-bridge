module Quickbooks
  module Reports
    class Parameters < Data.define(
      :report_type,
      :start_date,
      :end_date,
      :as_of_date,
      :accounting_method
    )
      REPORT_TYPES = %i[profit_and_loss balance_sheet cash_flow general_ledger trial_balance].freeze
      PERIOD_REPORT_TYPES = %i[profit_and_loss cash_flow general_ledger trial_balance].freeze
      ACCOUNTING_METHODS = %w[Cash Accrual].freeze

      def self.build(report_type:, attributes: {}, today: Date.current)
        unless REPORT_TYPES.include?(report_type)
          invalid!("The requested financial report is not supported.")
        end

        values = attributes.stringify_keys
        accounting_method = accounting_method_for(report_type, values["accounting_method"])

        if PERIOD_REPORT_TYPES.include?(report_type)
          if values["as_of_date"].present?
            invalid!("as_of_date is only accepted for Balance Sheet.")
          end

          end_date = parse_date(values["end_date"], field: "end_date", default: today)
          start_date =
            parse_date(values["start_date"], field: "start_date", default: end_date.prev_month(6))
          validate_period!(start_date, end_date)

          return(
            new(
              report_type: report_type,
              start_date: start_date,
              end_date: end_date,
              as_of_date: nil,
              accounting_method: accounting_method
            )
          )
        end

        if values["start_date"].present? || values["end_date"].present?
          invalid!("Balance Sheet accepts as_of_date instead of start_date or end_date.")
        end

        new(
          report_type: report_type,
          start_date: nil,
          end_date: nil,
          as_of_date: parse_date(values["as_of_date"], field: "as_of_date", default: today),
          accounting_method: accounting_method
        )
      end

      def quickbooks_params
        if report_type == :balance_sheet
          return { end_date: as_of_date.iso8601, accounting_method: accounting_method }
        end

        params = { start_date: start_date.iso8601, end_date: end_date.iso8601 }
        params[:accounting_method] = accounting_method if accounting_method
        params
      end

      def filters
        {
          start_date: start_date&.iso8601,
          end_date: end_date&.iso8601,
          as_of_date: as_of_date&.iso8601,
          accounting_method: accounting_method
        }
      end

      class << self
        private

        def accounting_method_for(report_type, value)
          if report_type == :cash_flow
            invalid!("accounting_method is not supported for Cash Flow.") if value.present?
            return
          end

          return "Accrual" if value.blank?

          method = value.to_s
          return method if ACCOUNTING_METHODS.include?(method)

          invalid!("accounting_method must be Cash or Accrual.")
        end

        def parse_date(value, field:, default:)
          return default if value.blank?

          string = value.to_s
          date = Date.iso8601(string)
          return date if date.iso8601 == string

          invalid!("#{field} must be an ISO 8601 date in YYYY-MM-DD format.")
        rescue Date::Error
          invalid!("#{field} must be an ISO 8601 date in YYYY-MM-DD format.")
        end

        def validate_period!(start_date, end_date)
          invalid!("end_date must be after start_date.") if end_date <= start_date
          return unless end_date > start_date.next_month(6)

          invalid!("Financial report date ranges cannot exceed six calendar months.")
        end

        def invalid!(message)
          raise Error::Validation.new(
                  message,
                  code: "quickbooks_report_parameters_invalid",
                  http_status: :unprocessable_entity
                )
        end
      end
    end
  end
end
