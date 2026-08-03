module Internal
  module V1
    module Quickbooks
      class BillPaymentsController < ::Api::V1::Quickbooks::BillPaymentsController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
