default_mode = Rails.env.production? ? "disabled" : "loopback"
mode = ENV.fetch("QUICKBOOKS_INTERNAL_API_AUTH_MODE", default_mode)
unless %w[disabled loopback].include?(mode)
  raise "QUICKBOOKS_INTERNAL_API_AUTH_MODE must be disabled or loopback"
end
if Rails.env.production? && mode == "loopback"
  raise "QUICKBOOKS_INTERNAL_API_AUTH_MODE=loopback is forbidden in production"
end

Rails.application.config.x.quickbooks.internal_api_auth_mode = mode
