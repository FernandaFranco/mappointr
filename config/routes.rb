Rails.application.routes.draw do
  devise_for :users

  # Login como visitante, sem cadastro — ver GuestSessionsController
  post "guest_session", to: "guest_sessions#create"

  # "Reivindicar" a conta de visitante como uma conta de verdade, mantendo o
  # histórico da sessão — ver GuestClaimsController
  resource :guest_claim, only: [ :new, :create ]

  # Rotas do jogo
  # GET  /play     → Inicia nova rodada (sorteia país, mostra mapa)
  # POST /play     → Processa chute do jogador
  # GET  /play/:id → Mostra resultado de uma rodada específica
  resources :games, path: "play", only: [ :new, :create, :show ]

  # Estatísticas do jogador logado
  resource :stats, only: :show

  # Salas multiplayer em tempo real
  post "rooms/join", to: "rooms#join", as: :join_room
  resources :rooms, only: [ :new, :create, :show ] do
    member do
      post :start
      post :advance
    end
    resources :guesses, only: [ :create ], controller: "room_guesses"
  end

  # Página inicial redireciona para o jogo
  root "games#new"

  # Health check para deploy
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
