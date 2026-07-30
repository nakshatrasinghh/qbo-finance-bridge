ENV["RAILS_ENV"] ||= "test"
ENV["QUICKBOOKS_ENV"] = "sandbox"
ENV["QUICKBOOKS_CLIENT_ID"] = "test-client-id"
ENV["QUICKBOOKS_CLIENT_SECRET"] = "test-client-secret"
ENV["QUICKBOOKS_REDIRECT_URI"] = "https://example.test/quickbooks/connections/callback"
ENV["ENABLE_QUICKBOOKS_CONNECTION_DASHBOARD"] = "true"

require_relative "../config/environment"
require "rails/test_help"
