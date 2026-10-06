Forefront::Engine.routes.draw do
  devise_for :admins, class_name: "Forefront::Admin", path: "admins",
    controllers: {
      sessions: "forefront/admins/sessions",
      passwords: "forefront/admins/passwords",
      registrations: "forefront/admins/registrations"
    }

  root to: "dashboard#index"
  get "dashboard/metrics/:key", to: "dashboard_metrics#show", as: :dashboard_metric

  resources :admins, path: "staff", only: [ :index, :new, :create, :edit, :update ]
  resources :products, only: [ :index, :new, :create, :edit, :update ] do
    resource :api_key, only: [ :create ], controller: "product_api_keys"
  end
  resources :targets, only: [ :index, :new, :create, :edit, :update ]
  resources :audit_events, path: "audit_log", only: [ :index ]
  resources :sources, only: [ :index, :create, :edit, :update, :destroy ]
  resources :lost_reasons, only: [ :index, :create, :edit, :update, :destroy ]
  resource :settings, only: [ :show, :update ]
  resources :notifications, only: [ :index, :show ] do
    post :read_all, on: :collection
  end

  get "unassigned", to: "unassigned#index", as: :unassigned
  get "my_work", to: "my_work#index", as: :my_work
  get "performance", to: "performance#index", as: :performance
  get "performance/:id/trend", to: "performance#trend", as: :performance_trend
  resources :reports, only: [ :index, :show ]

  resources :tickets do
    resource :take, only: [ :create ]
    resource :deadline, only: [ :create ]
    resource :conversion, only: [ :create ]
    resources :activities, only: [:create, :edit, :update, :destroy], controller: 'activities'
    resources :assignments, only: [:create], controller: 'assignments'
    resources :status_histories, only: [:create], controller: 'status_histories'
      resources :followups, only: [:create, :update]
  end

  resources :leads do
    resource :take, only: [ :create ]
    resource :reopen, only: [ :create ]
    resource :deadline, only: [ :create ]
    resources :activities, only: [:create, :edit, :update, :destroy], controller: 'activities'
    resources :assignments, only: [:create], controller: 'assignments'
    resources :status_histories, only: [:create], controller: 'status_histories'
      resources :followups, only: [:create, :update]
    resource :payment, only: [ :new, :create ] do
      resources :installments, only: [ :create ]
      resources :receipts, only: [ :create ]
    end
    resource :lead_share, only: [ :create ]
    resource :awaiting_customer, only: [ :create, :destroy ]
  end

  resources :customers do
    resource :contact_reveal, only: [ :create ]
  end
  resources :campaigns, only: [ :index, :show, :new, :create, :edit, :update ] do
    resources :enquiries, only: [ :create ]
  end

  resources :unattached_receipts, only: [ :index ] do
    member do
      post :attach
      post :discard
    end
  end

  namespace :api do
    namespace :v1 do
      post "signup", to: "signups#create"
      post "receipts", to: "receipts#create"
    end
  end
end
