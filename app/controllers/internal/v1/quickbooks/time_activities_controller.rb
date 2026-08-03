module Internal
  module V1
    module Quickbooks
      class TimeActivitiesController < ::Api::V1::Quickbooks::TimeActivitiesController
        include ::Quickbooks::InternalConnectionScoped
      end
    end
  end
end
