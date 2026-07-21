module Quickbooks
  module Reports
    class Serializer
      def self.call(report)
        {
          "type" => report.report_type.to_s,
          "title" => report.title,
          "basis" => report.basis,
          "currency" => report.currency,
          "generated_at" => report.generated_at,
          "start_date" => report.start_date,
          "end_date" => report.end_date,
          "no_data" => report.no_data,
          "columns" =>
            report.columns.map do |column|
              { "title" => column.title, "type" => column.column_type }
            end,
          "rows" =>
            report.rows.map do |row|
              {
                "kind" => row.kind,
                "group" => row.group,
                "depth" => row.depth,
                "cells" => row.cells.map { |cell| { "value" => cell.value, "id" => cell.id } }
              }
            end
        }
      end
    end
  end
end
