module Internal
  module V1
    module Quickbooks
      class StatusController < ::Api::V1::Quickbooks::BaseController
        include ::Quickbooks::InternalConnectionScoped

        skip_before_action :set_current_quickbooks_connection!
        skip_after_action :set_quickbooks_connection_generation!

        def show
          state = quickbooks_connection_store.fetch_current ? "connected" : "reconnect_required"
          render json: { connection: { state: } }
        end
      end
    end
  end
end
