module Quickbooks
  module Reports
    Column = Data.define(:title, :column_type)
    Cell = Data.define(:value, :id)
    Row = Data.define(:kind, :group, :depth, :cells)

    class Details < Data.define(
      :report_type,
      :title,
      :basis,
      :currency,
      :generated_at,
      :start_date,
      :end_date,
      :no_data,
      :columns,
      :rows
    )
      def self.from_payload(report_type:, payload:)
        Parser.new(report_type: report_type, payload: payload).call
      end
    end

    class Parser
      TITLES = {
        profit_and_loss: "Profit & Loss",
        balance_sheet: "Balance Sheet",
        cash_flow: "Cash Flow Statement",
        general_ledger: "General Ledger",
        trial_balance: "Trial Balance"
      }.freeze

      def initialize(report_type:, payload:)
        @report_type = report_type
        @payload = payload
      end

      def call
        unless payload.is_a?(Hash)
          unexpected!("QuickBooks returned an invalid financial report object.")
        end

        header = payload["Header"]
        raw_columns = payload.dig("Columns", "Column")
        raw_rows = payload.dig("Rows", "Row")
        unless header.is_a?(Hash)
          unexpected!("QuickBooks returned incomplete financial report metadata.")
        end
        unless raw_columns.is_a?(Array)
          unexpected!("QuickBooks returned invalid financial report columns.")
        end
        unless raw_rows.nil? || raw_rows.is_a?(Array)
          unexpected!("QuickBooks returned invalid financial report rows.")
        end

        columns = build_columns(raw_columns).freeze
        unexpected!("QuickBooks returned no financial report columns.") if columns.empty?

        rows = []
        append_rows!(rows, raw_rows || [], columns: columns, depth: 0)

        Details.new(
          report_type: report_type,
          title: TITLES.fetch(report_type),
          basis: report_basis(header),
          currency: currency(header),
          generated_at: timestamp(header),
          start_date: optional_date(header["StartPeriod"], field: "StartPeriod"),
          end_date: optional_date(header["EndPeriod"], field: "EndPeriod"),
          no_data: no_report_data?(header),
          columns: columns,
          rows: rows.freeze
        )
      rescue KeyError
        unexpected!("QuickBooks returned an unknown financial report type.")
      end

      private

      attr_reader :payload, :report_type

      def build_columns(raw_columns)
        raw_columns.flat_map do |raw_column|
          unless raw_column.is_a?(Hash)
            unexpected!("QuickBooks returned an invalid financial report column.")
          end

          nested = raw_column.dig("Columns", "Column")
          next build_columns(nested) if nested.is_a?(Array)

          column_type = raw_column["ColType"].to_s
          if column_type.blank?
            unexpected!("QuickBooks returned an incomplete financial report column.")
          end

          Column.new(title: raw_column["ColTitle"].to_s, column_type: column_type)
        end
      end

      def append_rows!(target, raw_rows, columns:, depth:)
        raw_rows.each do |raw_row|
          unless raw_row.is_a?(Hash)
            unexpected!("QuickBooks returned an invalid financial report row.")
          end

          case raw_row["type"]
          when "Data"
            target << build_row("data", raw_row["group"], depth, raw_row["ColData"], columns)
          when "Section"
            append_section!(target, raw_row, columns: columns, depth: depth)
          when nil
            if raw_row["ColData"].is_a?(Array)
              target << build_row("data", raw_row["group"], depth, raw_row["ColData"], columns)
            else
              unexpected!("QuickBooks returned an unknown financial report row type.")
            end
          else
            unexpected!("QuickBooks returned an unknown financial report row type.")
          end
        end
      end

      def append_section!(target, raw_row, columns:, depth:)
        header_cells = raw_row.dig("Header", "ColData")
        if header_cells
          target << build_row("section", raw_row["group"], depth, header_cells, columns)
        end

        nested_rows = raw_row.dig("Rows", "Row")
        unless nested_rows.nil? || nested_rows.is_a?(Array)
          unexpected!("QuickBooks returned invalid nested financial report rows.")
        end
        append_rows!(target, nested_rows || [], columns: columns, depth: depth + 1)

        summary_cells = raw_row.dig("Summary", "ColData")
        if summary_cells
          target << build_row("summary", raw_row["group"], depth, summary_cells, columns)
        end
      end

      def build_row(kind, group, depth, raw_cells, columns)
        unless raw_cells.is_a?(Array)
          unexpected!("QuickBooks returned invalid financial report cells.")
        end
        if raw_cells.length != columns.length
          unexpected!("QuickBooks returned financial report cells that do not match its columns.")
        end

        cells =
          raw_cells
            .each_with_index
            .map do |raw_cell, index|
              unless raw_cell.is_a?(Hash)
                unexpected!("QuickBooks returned an invalid financial report cell.")
              end

              value = raw_cell["value"]
              unless value.nil? || value.is_a?(String)
                unexpected!("QuickBooks returned a non-string financial report cell.")
              end
              validate_money!(value, columns[index])

              Cell.new(value: value.presence, id: raw_cell["id"].presence&.to_s)
            end
            .freeze

        Row.new(kind: kind, group: group.presence&.to_s, depth: depth, cells: cells)
      end

      def validate_money!(value, column)
        return unless column.column_type == "Money" && value.present?
        return if BigDecimal(value, exception: false)

        unexpected!("QuickBooks returned an invalid decimal report amount.")
      end

      def report_basis(header)
        basis = header["ReportBasis"].to_s
        return if report_type == :cash_flow && basis.blank?
        return basis if Parameters::ACCOUNTING_METHODS.include?(basis)

        unexpected!("QuickBooks returned an invalid financial report basis.")
      end

      def currency(header)
        value = header["Currency"].to_s
        return value if value.match?(/\A[A-Z]{3}\z/)

        unexpected!("QuickBooks returned an invalid financial report currency.")
      end

      def timestamp(header)
        value = header["Time"].to_s
        Time.iso8601(value)
        value
      rescue ArgumentError
        unexpected!("QuickBooks returned an invalid financial report timestamp.")
      end

      def optional_date(value, field:)
        return if value.blank?

        string = value.to_s
        date = Date.iso8601(string)
        return string if date.iso8601 == string

        unexpected!("QuickBooks returned an invalid financial report #{field}.")
      rescue Date::Error
        unexpected!("QuickBooks returned an invalid financial report #{field}.")
      end

      def no_report_data?(header)
        option =
          Array(header["Option"]).find do |candidate|
            candidate.is_a?(Hash) && candidate["Name"] == "NoReportData"
          end
        return false unless option
        return true if option["Value"] == "true"
        return false if option["Value"] == "false"

        unexpected!("QuickBooks returned an invalid NoReportData option.")
      end

      def unexpected!(message)
        raise Error::UnexpectedResponse.new(
                message,
                code: "quickbooks_financial_report_unexpected",
                http_status: :bad_gateway
              )
      end
    end
  end
end
