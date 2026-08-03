module Internal
  module V1
    module Quickbooks
      class BillsController < ::Api::V1::Quickbooks::BillsController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
