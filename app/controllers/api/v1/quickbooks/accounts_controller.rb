module Api
  module V1
    module Quickbooks
      class AccountsController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          accounts =
            ::Quickbooks::Accounts::Query
              .new(connection: connection)
              .call
              .select { |account| ::Quickbooks::JournalEntries::Create.eligible_account?(account) }

          render json: {
                   accounts:
                     accounts.map do |account|
                       {
                         id: account.id,
                         name: account.name,
                         display_name: account.display_name,
                         account_type: account.account_type,
                         account_subtype: account.account_subtype,
                         classification: account.classification
                       }
                     end
                 }
        end
      end
    end
  end
end
