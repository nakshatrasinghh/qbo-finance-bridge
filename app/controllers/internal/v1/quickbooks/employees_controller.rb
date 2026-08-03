module Internal
  module V1
    module Quickbooks
      class EmployeesController < ::Api::V1::Quickbooks::EmployeesController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
