module Api
  module V1
    module Quickbooks
      class TimeActivitiesController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          activities = ::Quickbooks::TimeActivities::Query.new(connection: connection).call

          render json: {
                   time_activities:
                     activities.map do |activity|
                       ::Quickbooks::TimeActivities::Serializer.call(activity)
                     end
                 }
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::TimeActivities::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: time_activity_params.to_h
            ).call

          render_create(result)
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

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   time_activity: result.time_activity,
                   idempotency: {
                     replayed: result.replayed,
                     operation_id: result.operation.id
                   }
                 },
                 status: result.replayed ? :ok : :created
        end
      end
    end
  end
end
