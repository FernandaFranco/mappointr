Rails.application.routes.draw do
  # Sem login: ApplicationController#set_current_user cria um jogador na
  # primeira request. Só em teste, pra sistema poder fixar qual jogador uma
  # sessão de browser representa (Capybara não compartilha memória com o
  # processo de teste, então não dá pra escrever direto em `session`).
  get "test_sign_in/:user_id", to: "test_sign_ins#create", as: :test_sign_in if Rails.env.test?

  # Rotas do jogo
  # GET  /play     → Inicia nova rodada (sorteia país, mostra mapa)
  # POST /play     → Processa chute do jogador
  # GET  /play/:id → Mostra resultado de uma rodada específica
  resources :games, path: "play", only: [ :new, :create, :show ]

  # Estatísticas globais por país, públicas
  resource :stats, only: :show
  # Estatísticas + pontos de chute de um país só, carregado via turbo-frame
  # ao clicar nele no mapa da página de estatísticas — ver StatsController#country
  get "stats/:country_id", to: "stats#country", as: :country_stats

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
