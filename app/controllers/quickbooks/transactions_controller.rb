module Quickbooks
  class TransactionsController < BaseController
    def show
      @connection = QuickbooksConnection.find(params[:connection_id])
    end
  end
end
