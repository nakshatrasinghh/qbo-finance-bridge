module Internal
  module V1
    module Quickbooks
      class InvoicesController < ::Api::V1::Quickbooks::InvoicesController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
