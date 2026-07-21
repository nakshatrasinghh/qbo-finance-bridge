module Quickbooks
  class JournalEntriesController < BaseController
    def index
      @connection = QuickbooksConnection.find(params[:connection_id])
    end
  end
end
