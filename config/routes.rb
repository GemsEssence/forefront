Forefront::Engine.routes.draw do
  devise_for :admins, class_name: "Forefront::Admin", path: "admins",
    controllers: {
      sessions: "forefront/admins/sessions",
      passwords: "forefront/admins/passwords",
      registrations: "forefront/admins/registrations"
    }

  root to: "dashboard#index"

  resources :admins, path: "staff", only: [ :index, :new, :create, :edit, :update ]
  resources :products, only: [ :index, :new, :create, :edit, :update ]
  resources :targets, only: [ :index, :new, :create, :edit, :update ]
  resources :audit_events, path: "audit_log", only: [ :index ]

  resources :tickets do
    resources :activities, only: [:create, :edit, :update, :destroy], controller: 'activities'
    resources :assignments, only: [:create], controller: 'assignments'
    resources :status_histories, only: [:create], controller: 'status_histories'
      resources :followups, only: [:create, :update]
  end

  resources :leads do
    resources :activities, only: [:create, :edit, :update, :destroy], controller: 'activities'
    resources :assignments, only: [:create], controller: 'assignments'
    resources :status_histories, only: [:create], controller: 'status_histories'
      resources :followups, only: [:create, :update]
    resource :payment, only: [ :new, :create, :update ] do
      resources :installments, only: [ :create, :update ]
    end
    resource :lead_share, only: [ :create ]
  end

  resources :customers
end
