Forefront::Engine.routes.draw do
  devise_for :admins, class_name: "Forefront::Admin", path: "admins"

  root to: "dashboard#index"

  resources :tickets
  resources :leads
  resources :customers
end
