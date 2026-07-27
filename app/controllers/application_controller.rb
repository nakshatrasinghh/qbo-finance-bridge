class ApplicationController < ActionController::Base
  # Only allow modern browsers.
  allow_browser versions: :modern
end
