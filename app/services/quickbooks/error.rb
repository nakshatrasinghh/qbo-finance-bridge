module Quickbooks
  class Error < StandardError
    attr_reader :code, :details, :http_status, :upstream_status

    def initialize(message, code:, http_status:, details: {}, upstream_status: nil)
      super(message)
      @code = code
      @details = details.freeze
      @http_status = http_status
      @upstream_status = upstream_status
    end

    class Configuration < Error
    end
    class Authentication < Error
    end
    class Authorization < Error
    end
    class Validation < Error
    end
    class NotFound < Error
    end
    class Conflict < Error
    end
    class RateLimit < Error
    end
    class Timeout < Error
    end
    class Unavailable < Error
    end
    class UnexpectedResponse < Error
    end
  end
end
