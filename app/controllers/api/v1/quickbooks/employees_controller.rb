module Api
  module V1
    module Quickbooks
      class EmployeesController < BaseController
        def index
          employees = ::Quickbooks::Employees::Query.new(connection: @connection).call

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
          result =
            ::Quickbooks::Employees::Submit.new(
              connection: @connection,
              attributes: employee_params.to_h
            ).call

          render json: { employee: result.employee }, status: :created
        end

        private

        def employee_params
          params.require(:employee).permit(:given_name, :family_name, :email, :phone)
        end
      end
    end
  end
end
