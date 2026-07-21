module Api
  module V1
    module Quickbooks
      class EmployeesController < BaseController
        def index
          connection = QuickbooksConnection.find(params[:connection_id])
          employees = ::Quickbooks::Employees::Query.new(connection: connection).call

          render json: {
                   employees:
                     employees.map { |employee|
                       ::Quickbooks::Employees::Serializer.call(employee)
                     },
                   capabilities: {
                     employee_records: true,
                     full_payroll: false
                   }
                 }
        end

        def create
          connection = QuickbooksConnection.find(params[:connection_id])
          result =
            ::Quickbooks::Employees::Submit.new(
              connection: connection,
              idempotency_key: request.headers["Idempotency-Key"],
              attributes: employee_params.to_h
            ).call

          render_create(result)
        end

        private

        def employee_params
          params.require(:employee).permit(:given_name, :family_name, :email, :phone)
        end

        def render_create(result)
          response.set_header("Idempotency-Replayed", result.replayed.to_s)
          render json: {
                   employee: result.employee,
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
