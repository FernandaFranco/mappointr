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

  # Jogadores da sala que não têm nenhuma jogada nesta rodada — não criamos
  # mais uma jogada sintética pra eles (ver histórico do finalize!), então
  # ficam de fora de game_rounds e precisam ser listados à parte na view.
  def unanswered_players
    room.room_players.where.not(user_id: game_rounds.select(:user_id))
  end

  # Marca a rodada como encerrada. Usa update_all condicionado a status:
  # :active como transição atômica — se dois requests chegarem aqui ao
  # mesmo tempo, só um "ganha" a corrida (affected rows == 1) e executa o
  # efeito colateral (pontuação) uma única vez.
  def finalize!
    claimed = RoomRound.where(id: id, status: :active).update_all(status: :finished, ended_at: Time.current)
    return false if claimed.zero?

    # update_all não atualiza os atributos em memória deste objeto — sem o
    # reload, quem chamar finalize! e em seguida ler ended_at/status (ex: pra
    # transmitir via broadcast) veria os valores antigos.
    reload

    award_points!
    true
  end

  private

  def award_points!
    game_rounds.reload.each do |game_round|
      points = RESULT_POINTS.fetch(game_round.result, 0)
      next if points.zero?

      RoomPlayer.where(room_id: room_id, user_id: game_round.user_id)
                .update_all([ "score = score + ?", points ])
    end
  end
end
