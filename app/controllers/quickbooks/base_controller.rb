module Quickbooks
  class BaseController < ApplicationController
    before_action :ensure_dashboard_enabled!

    private

    def configuration
      @configuration ||= Configuration.new
    end

    def ensure_dashboard_enabled!
      return if configuration.dashboard_enabled?

      raise ActionController::RoutingError, "Not Found"
    end
  end
end
