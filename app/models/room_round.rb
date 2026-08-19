class RoomRound < ApplicationRecord
  RESULT_POINTS = { "correct" => 1000, "close" => 500, "wrong" => 0 }.freeze

  belongs_to :room
  belongs_to :country
  has_many :game_rounds

  enum :status, { active: 0, finished: 1 }, default: :active

  validates :round_number, uniqueness: { scope: :room_id }

  def all_answered?
    game_rounds.count >= room.room_players.count
  end

  def time_elapsed?
    started_at.present? && Time.current >= started_at + room.round_duration_seconds
  end

  def due_for_finalization?
    active? && (all_answered? || time_elapsed?)
  end

  # Marca a rodada como encerrada. Usa update_all condicionado a status:
  # :active como transição atômica — se dois requests chegarem aqui ao
  # mesmo tempo, só um "ganha" a corrida (affected rows == 1) e executa os
  # efeitos colaterais (jogadas sintéticas + pontuação) uma única vez.
  def finalize!
    claimed = RoomRound.where(id: id, status: :active).update_all(status: :finished, ended_at: Time.current)
    return false if claimed.zero?

    # update_all não atualiza os atributos em memória deste objeto — sem o
    # reload, quem chamar finalize! e em seguida ler ended_at/status (ex: pra
    # transmitir via broadcast) veria os valores antigos.
    reload

    fill_missing_guesses!
    award_points!
    true
  end

  private

  # Jogador que não respondeu a tempo recebe uma jogada "wrong" automática,
  # usando o ponto antípoda do país (sempre longe o bastante pra dar wrong),
  # assim toda rodada tem uma linha por jogador e placar/estatísticas
  # continuam consistentes entre rodadas.
  def fill_missing_guesses!
    answered_user_ids = game_rounds.pluck(:user_id)
    missing_players = room.room_players.where.not(user_id: answered_user_ids)

    missing_players.find_each do |room_player|
      point = antipodal_point
      GameRound.create!(
        user: room_player.user,
        country: country,
        room_round: self,
        guessed_lat: point[:lat],
        guessed_lng: point[:lng],
        time_seconds: room.round_duration_seconds
      )
    end
  end

  def antipodal_point
    centroid = country.centroid || { lat: 0.0, lng: 0.0 }
    lat = -centroid[:lat]
    lng = centroid[:lng].positive? ? centroid[:lng] - 180 : centroid[:lng] + 180
    { lat: lat, lng: lng }
  end

  def award_points!
    game_rounds.reload.each do |game_round|
      points = RESULT_POINTS.fetch(game_round.result, 0)
      next if points.zero?

      RoomPlayer.where(room_id: room_id, user_id: game_round.user_id)
                .update_all([ "score = score + ?", points ])
    end
  end
end
