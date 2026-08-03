module Internal
  module V1
    module Quickbooks
      class CustomersController < ::Api::V1::Quickbooks::CustomersController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
