module Internal
  module V1
    module Quickbooks
      class JournalEntriesController < ::Api::V1::Quickbooks::JournalEntriesController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
