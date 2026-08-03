Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up", to: "rails/health#show", as: :rails_health_check

  # Stable JSON liveness contract for local callers and deployment probes.
  get "health", to: "health#show", as: :health

  get "api-docs", to: "api_docs#show", as: :api_docs
  get "api-docs/openapi.yaml", to: "api_docs#openapi", as: :api_docs_openapi

  namespace :quickbooks do
    resources :connections, only: %i[index show] do
      resources :journal_entries, only: :index
      resource :operations, only: :show, controller: "operations"
      resource :transactions, only: :show, controller: "transactions"

      collection do
        get :connect
        get :callback
      end

      member { delete :disconnect }
    end
  end

  namespace :internal do
    namespace :v1 do
      namespace :quickbooks do
        resource :status, only: :show, controller: "status"
        resources :accounts,
                  :employees,
                  :time_activities,
                  :tax_codes,
                  :inventory_items,
                  :customers,
                  :vendors,
                  :invoices,
                  :bills,
                  :customer_payments,
                  :bill_payments,
                  :journal_entries,
                  only: :index

        get "reports/profit_and_loss", to: "financial_reports#profit_and_loss"
        get "reports/balance_sheet", to: "financial_reports#balance_sheet"
        get "reports/cash_flow", to: "financial_reports#cash_flow"
        get "reports/general_ledger", to: "financial_reports#general_ledger"
        get "reports/trial_balance", to: "financial_reports#trial_balance"
      end
    end
  end

  namespace :api do
    namespace :v1 do
      namespace :quickbooks do
        resources :connections, only: [] do
          resources :accounts, only: :index
          resources :employees, only: %i[index create]
          resources :time_activities, only: %i[index create]
          resources :tax_codes, only: %i[index create]
          resources :inventory_items, only: %i[index create]
          resources :customers, only: %i[index create]
          resources :vendors, only: %i[index create]
          resources :invoices, only: %i[index create]
          resources :bills, only: %i[index create]
          resources :customer_payments, only: %i[index create]
          resources :bill_payments, only: %i[index create]
          resources :journal_entries, only: %i[index create]

          get "reports/profit_and_loss",
              to: "financial_reports#profit_and_loss",
              as: :profit_and_loss_report
          get "reports/balance_sheet",
              to: "financial_reports#balance_sheet",
              as: :balance_sheet_report
          get "reports/cash_flow", to: "financial_reports#cash_flow", as: :cash_flow_report
          get "reports/general_ledger",
              to: "financial_reports#general_ledger",
              as: :general_ledger_report
          get "reports/trial_balance",
              to: "financial_reports#trial_balance",
              as: :trial_balance_report
        end
      end
    end
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
