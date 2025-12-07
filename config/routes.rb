Forefront::Engine.routes.draw do
  devise_for :admins, class_name: "Forefront::Admin", path: "admins"

  root to: "dashboard#index"

  resources :tickets do
    resources :activities, only: [:create, :edit, :update, :destroy], controller: 'activities'
    resources :assignments, only: [:create], controller: 'assignments'
    resources :status_histories, only: [:create], controller: 'status_histories'
  end

  resources :leads do
    resources :activities, only: [:create, :edit, :update, :destroy], controller: 'activities'
    resources :assignments, only: [:create], controller: 'assignments'
    resources :status_histories, only: [:create], controller: 'status_histories'
  end

  resources :customers
end
