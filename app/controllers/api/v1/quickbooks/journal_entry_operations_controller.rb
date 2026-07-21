module Api
  module V1
    module Quickbooks
      class JournalEntryOperationsController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          page =
            ::Quickbooks::JournalEntries::AuditHistory.new(
              connection: connection,
              parameters: journal_entry_read_parameters
            ).call

          render json: {
                   journal_entry_operations:
                     page.records.map do |operation|
                       ::Quickbooks::JournalEntries::AuditSerializer.call(operation)
                     end,
                   pagination: page.pagination,
                   filters: page.filters
                 }
        end

        private

        def journal_entry_read_parameters
          ::Quickbooks::JournalEntries::ReadParameters.build(
            params
              .permit(:connection_id, :txn_date_from, :txn_date_to, :page, :per_page)
              .to_h
              .except("connection_id")
          )
        end
      end
    end
  end
end
