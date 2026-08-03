module Internal
  module V1
    module Quickbooks
      class VendorsController < ::Api::V1::Quickbooks::VendorsController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
