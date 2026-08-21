class GamesController < ApplicationController
  # Requer login para jogar
  before_action :authenticate_user!

  # GET /play/new (ou /)
  # Inicia uma nova rodada: sorteia país (considerando a dificuldade
  # sugerida para o jogador) e mostra o mapa
  def new
    @country = Country.random(difficulty: current_user.next_difficulty)

    # Nenhum país jogável disponível (tabela vazia ou tudo excluded)
    if @country.nil?
      render :unavailable, status: :service_unavailable
      return
    end

    # Guarda o país sorteado e o tempo de início na sessão
    # Isso evita que o jogador trapaceie recarregando a página
    session[:current_country_id] = @country.id
    session[:round_started_at] = Time.current.to_i
  end

  # POST /play
  # Processa o chute do jogador
  def create
    # Recupera o país da sessão (o que foi sorteado)
    @country = Country.find_by(id: session[:current_country_id])

    # Proteção contra requests inválidos
    if @country.nil?
      redirect_to new_game_path, alert: "Sessão expirada. Começando nova rodada."
      return
    end

    # Calcula o tempo que o jogador levou
    started_at = session[:round_started_at] || Time.current.to_i
    time_seconds = Time.current.to_i - started_at

    # Cria o registro da jogada
    @game_round = current_user.game_rounds.build(
      country: @country,
      guessed_lat: params[:lat].to_f,
      guessed_lng: params[:lng].to_f,
      time_seconds: [ time_seconds, 1 ].max # Mínimo 1 segundo
    )

    if @game_round.save
      # Limpa a sessão para a próxima rodada
      session.delete(:current_country_id)
      session.delete(:round_started_at)

      # Redireciona para ver o resultado
      redirect_to game_path(@game_round)
    else
      # Se houver erro de validação, volta para o jogo
      flash.now[:alert] = "Erro ao salvar jogada: #{@game_round.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  # GET /play/:id
  # Mostra o resultado de uma rodada
  def show
    @game_round = current_user.game_rounds.find(params[:id])
    @country = @game_round.country

    # Estatísticas comparativas com outros jogadores
    @stats = calculate_stats(@game_round)

    # Mapa de calor com todo chute já feito neste país (anônimo, agregado em
    # grade — ver GameRound.heatmap_points). Só faz sentido mostrar junto com
    # a comparação: sem outros chutes, seria só o próprio ponto do jogador.
    @heatmap_points = @stats[:total_attempts] > 1 ? GameRound.heatmap_points(@country.id) : []

    # Amostra de chutes individuais e anônimos (posição + resultado, sem
    # identidade nenhuma) pra desenhar em cima do mapa de calor — mesma
    # condição de exibição, já que sem outros chutes não há nada pra amostrar.
    @sample_points = @stats[:total_attempts] > 1 ? GameRound.sample_points(@country.id) : []
  end

  private

  # Calcula estatísticas comparativas para esta rodada
  def calculate_stats(game_round)
    # Todas as jogadas deste país
    country_rounds = GameRound.for_country(game_round.country_id)

    # Total de jogadores que tentaram este país
    total_attempts = country_rounds.count

    # Quantos acertaram (correct)
    correct_count = country_rounds.correct.count

    # Quantos chegaram perto (close)
    close_count = country_rounds.close.count

    # Percentil de distância (quantos % foram piores que você)
    worse_distance_count = country_rounds.where("distance_km > ?", game_round.distance_km).count
    distance_percentile = total_attempts > 1 ? (worse_distance_count.to_f / (total_attempts - 1) * 100).round(0) : 100

    # Percentil de tempo (quantos % foram mais lentos que você)
    slower_count = country_rounds.where("time_seconds > ?", game_round.time_seconds).count
    time_percentile = total_attempts > 1 ? (slower_count.to_f / (total_attempts - 1) * 100).round(0) : 100

    {
      total_attempts: total_attempts,
      correct_percentage: total_attempts > 0 ? (correct_count.to_f / total_attempts * 100).round(1) : 0,
      close_percentage: total_attempts > 0 ? (close_count.to_f / total_attempts * 100).round(1) : 0,
      distance_percentile: distance_percentile,
      time_percentile: time_percentile
    }
  end
end
