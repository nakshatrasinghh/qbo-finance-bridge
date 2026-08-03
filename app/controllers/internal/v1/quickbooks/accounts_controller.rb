module Internal
  module V1
    module Quickbooks
      class AccountsController < ::Api::V1::Quickbooks::AccountsController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
