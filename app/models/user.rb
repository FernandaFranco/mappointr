class User < ApplicationRecord
  # Relacionamentos
  has_many :game_rounds, dependent: :destroy
  has_many :room_players, dependent: :destroy
  has_many :rooms, through: :room_players

  validates :display_name, presence: true

  # Cria um jogador novo com um apelido gerado. Não existe conta "de
  # verdade" nem login — session[:user_id] (ver ApplicationController) é a
  # única forma de identidade. Reaproveita current_user/GameRound/RoomPlayer
  # sem alterar nenhuma associação.
  def self.create_player!
    create!(display_name: "Visitante #{rand(1000..9999)}")
  end

  # Métodos de estatísticas do usuário
  def total_games
    game_rounds.count
  end

  def correct_games
    game_rounds.correct_guesses.count
  end

  def close_games
    game_rounds.close_guesses.count
  end

  def successful_games
    game_rounds.successful_guesses.count
  end

  def wrong_games
    game_rounds.wrong.count
  end

  # Porcentagem de acertos exatos (dentro do país)
  def accuracy_percentage
    return 0 if total_games.zero?
    (correct_games.to_f / total_games * 100).round(1)
  end

  # Porcentagem de sucesso (acertos + quase)
  def success_percentage
    return 0 if total_games.zero?
    (successful_games.to_f / total_games * 100).round(1)
  end

  # Quantas rodadas recentes olhamos para decidir a próxima dificuldade
  ROUNDS_WINDOW = 10
  # Mínimo de rodadas jogadas antes de sair do padrão :medium
  MIN_ROUNDS_FOR_PROGRESSION = 5
  HARD_THRESHOLD_PERCENTAGE = 70
  EASY_THRESHOLD_PERCENTAGE = 40

  # Dificuldade sugerida para a próxima rodada, baseada nas últimas
  # ROUNDS_WINDOW jogadas (não na média histórica) — assim o jogo reage a
  # uma melhora ou piora recente, não fica preso ao desempenho lá do início.
  # Jogadas de sala (room_round_id presente) não entram na janela: o país
  # de uma rodada de sala é sorteado pela dificuldade da sala, não pelo
  # desempenho individual do jogador, então não é um sinal válido aqui.
  def next_difficulty
    recent_ids = game_rounds.where(room_round_id: nil).order(created_at: :desc).limit(ROUNDS_WINDOW).pluck(:id)
    return :medium if recent_ids.size < MIN_ROUNDS_FOR_PROGRESSION

    successful_count = GameRound.where(id: recent_ids).successful_guesses.count
    success_rate = successful_count.to_f / recent_ids.size * 100

    if success_rate >= HARD_THRESHOLD_PERCENTAGE
      :hard
    elsif success_rate >= EASY_THRESHOLD_PERCENTAGE
      :medium
    else
      :easy
    end
  end
end
