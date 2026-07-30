module Quickbooks
  module ConnectionScoped
    extend ActiveSupport::Concern

    included { before_action :set_quickbooks_connection }

    private

    def set_quickbooks_connection
      connection_id = owned_quickbooks_connection_id
      @connection = quickbooks_connection_store.fetch(connection_id)
      raise_reconnect_required!(clear_session: true) unless @connection
    end

    def owned_quickbooks_connection_id
      session_id = session_quickbooks_connection_id
      requested_id =
        request.path_parameters[:connection_id].presence || request.path_parameters[:id].presence
      return session_id if owns_connection?(session_id:, requested_id:)

      raise_reconnect_required!
    end

    def owns_connection?(session_id:, requested_id:)
      return false unless valid_connection_id?(session_id) && valid_connection_id?(requested_id)

      ActiveSupport::SecurityUtils.secure_compare(session_id, requested_id)
    end

    def valid_connection_id?(connection_id)
      connection_id.is_a?(String) && connection_id.match?(SandboxConnection::ID_FORMAT)
    end

    def raise_reconnect_required!(clear_session: false)
      clear_quickbooks_connection_session! if clear_session
      fail Error::ReconnectRequired.new(
             "The QuickBooks sandbox connection is missing or expired. Reconnect QuickBooks.",
             code: "quickbooks_reconnect_required",
             http_status: :unauthorized
           )
    end
  end
end
