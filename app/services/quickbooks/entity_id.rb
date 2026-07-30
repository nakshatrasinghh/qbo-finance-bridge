module Quickbooks
  module EntityId
    FORMAT = /\A[a-z0-9_.:-]{1,255}\z/i

    def self.valid?(value)
      value.is_a?(String) && value.match?(FORMAT)
    end
  end
end
