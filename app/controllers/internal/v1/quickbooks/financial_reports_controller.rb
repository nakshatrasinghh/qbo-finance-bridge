module Internal
  module V1
    module Quickbooks
      class FinancialReportsController < ::Api::V1::Quickbooks::FinancialReportsController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
