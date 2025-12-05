Forefront::Engine.routes.draw do
  root to: "dashboard#index"

  resources :tickets
  resources :leads
  resources :customers
end
