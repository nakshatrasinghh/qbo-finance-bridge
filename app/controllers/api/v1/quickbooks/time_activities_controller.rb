module Api
  module V1
    module Quickbooks
      class TimeActivitiesController < BaseController
        def index
          activities = ::Quickbooks::TimeActivities::Query.new(connection: @connection).call

          render json: {
                   time_activities:
                     activities.map do |activity|
                       ::Quickbooks::TimeActivities::Serializer.call(activity)
                     end
                 }
        end

        def create
          result =
            ::Quickbooks::TimeActivities::Submit.new(
              connection: @connection,
              attributes: time_activity_params.to_h
            ).call

          render json: { time_activity: result.time_activity }, status: :created
        end

        private

        def time_activity_params
          params.require(:time_activity).permit(
            :employee_id,
            :txn_date,
            :hours,
            :minutes,
            :description
          )
        end
      end
    end
  end
end
