Rails.application.routes.draw do
  devise_for :users

  # Rotas do jogo
  # GET  /play     → Inicia nova rodada (sorteia país, mostra mapa)
  # POST /play     → Processa chute do jogador
  # GET  /play/:id → Mostra resultado de uma rodada específica
  resources :games, path: "play", only: [ :new, :create, :show ]

  # Página inicial redireciona para o jogo
  root "games#new"

  # Health check para deploy
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
