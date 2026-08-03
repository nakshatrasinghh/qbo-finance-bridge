module Internal
  module V1
    module Quickbooks
      class CustomerPaymentsController < ::Api::V1::Quickbooks::CustomerPaymentsController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
