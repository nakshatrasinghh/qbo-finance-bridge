module Api
  module V1
    module Quickbooks
      class JournalEntriesController < BaseController
        def index
          page =
            ::Quickbooks::JournalEntries::Query.new(
              connection: @connection,
              parameters: journal_entry_read_parameters
            ).call

          render json: {
                   journal_entries:
                     page.records.map { |entry|
                       ::Quickbooks::JournalEntries::Serializer.call(entry)
                     },
                   pagination: page.pagination,
                   filters: page.filters
                 }
        end

        def create
          result =
            ::Quickbooks::JournalEntries::Submit.new(
              connection: @connection,
              attributes: journal_entry_params.to_h
            ).call

          render json: { journal_entry: result.journal_entry }, status: :created
        end

        private

        def journal_entry_params
          params.require(:journal_entry).permit(
            :txn_date,
            :memo,
            :amount,
            :debit_account_id,
            :credit_account_id
          )
        end

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
