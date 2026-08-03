module Internal
  module V1
    module Quickbooks
      class TaxCodesController < ::Api::V1::Quickbooks::TaxCodesController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
