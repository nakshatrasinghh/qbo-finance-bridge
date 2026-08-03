module Internal
  module V1
    module Quickbooks
      class InventoryItemsController < ::Api::V1::Quickbooks::InventoryItemsController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
