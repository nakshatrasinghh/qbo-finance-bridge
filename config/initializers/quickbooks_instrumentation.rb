Rails.application.config.after_initialize do
  %w[oauth.quickbooks request.quickbooks].each do |event_name|
    ActiveSupport::Notifications.subscribe(event_name) do |event|
      payload = event.payload
      log_data = {
        event: event.name,
        duration_ms: event.duration.round(1),
        operation: payload[:operation],
        connection_id: payload[:connection_id],
        realm_id: payload[:realm_id],
        method: payload[:method],
        path: payload[:path],
        request_id: payload[:request_id],
        retried: payload[:retried],
        status: payload[:status],
        intuit_tid: payload[:intuit_tid]
      }.compact
      Rails.logger.info(log_data.to_json)
    end
  end
end
