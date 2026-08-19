class Room < ApplicationRecord
  # Sem 0/O/1/I/L pra não confundir na hora de digitar o código
  CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ".chars
  CODE_LENGTH = 6

  MIN_PLAYERS = 2
  MAX_PLAYERS = 8
  # Pausa entre revelar o resultado de uma rodada e sortear a próxima
  REVEAL_PAUSE_SECONDS = 5
  # Sala sem nenhuma atividade por esse tempo é considerada abandonada
  STALE_AFTER = 30.minutes

  belongs_to :host, class_name: "User"
  belongs_to :current_room_round, class_name: "RoomRound", optional: true

  has_many :room_players, dependent: :destroy
  has_many :players, through: :room_players, source: :user
  has_many :room_rounds, dependent: :destroy

  # Enum de dificuldade: nil = "qualquer dificuldade"
  enum :difficulty, { easy: 0, medium: 1, hard: 2 }, prefix: true
  enum :status, { waiting: 0, in_progress: 1, finished: 2, expired: 3 }, default: :waiting

  validates :total_rounds, numericality: { greater_than: 0 }
  validates :round_duration_seconds, numericality: { greater_than: 0 }

  before_validation :generate_code, on: :create
  before_validation :set_last_activity_at, on: :create

  def full?
    room_players.count >= MAX_PLAYERS
  end

  def enough_players_to_start?
    room_players.count >= MIN_PLAYERS
  end

  def stale?
    !finished? && last_activity_at < STALE_AFTER.ago
  end

  def touch_activity!
    update_column(:last_activity_at, Time.current)
  end

  def start_next_round!
    country = Country.random(difficulty: difficulty)
    round_number = current_round_number + 1
    room_round = RoomRound.create!(room: self, country: country, round_number: round_number, started_at: Time.current)
    update!(current_round_number: round_number, current_room_round: room_round)
  end

  # Avança o estado da sala se (e só se) já for hora — recalcula tudo a
  # partir do banco antes de agir, então é seguro chamar a qualquer momento,
  # de múltiplas abas ao mesmo tempo, ou de um job em background (ver
  # RoomSweepJob). Deliberadamente NÃO chama touch_activity! — isso fica a
  # cargo de quem chamou (só uma request HTTP real conta como atividade;
  # se o job marcasse atividade também, uma sala verdadeiramente abandonada
  # nunca ficaria stale, porque o próprio sweep manteria ela "viva").
  def advance!
    with_lock do
      round = current_room_round

      if round&.due_for_finalization?
        round.finalize!
        broadcast_results
      elsif round&.finished? && Time.current >= round.ended_at + Room::REVEAL_PAUSE_SECONDS
        advance_past_reveal!
      end
    end
  end

  def broadcast_round
    broadcast_replace_to(self, target: "room_body", partial: "rooms/round",
      locals: { room: self, room_round: current_room_round })
  end

  def broadcast_results
    broadcast_replace_to(self, target: "room_body", partial: "rooms/results",
      locals: { room: self, room_round: current_room_round })
  end

  def broadcast_leaderboard
    broadcast_replace_to(self, target: "room_body", partial: "rooms/leaderboard", locals: { room: self })
  end

  private

  def advance_past_reveal!
    if current_round_number >= total_rounds
      update!(status: :finished)
      broadcast_leaderboard
    else
      start_next_round!
      broadcast_round
    end
  end

  def generate_code
    return if code.present?

    loop do
      self.code = Array.new(CODE_LENGTH) { CODE_ALPHABET.sample }.join
      break unless Room.exists?(code: code)
    end
  end

  def set_last_activity_at
    self.last_activity_at ||= Time.current
  end
end
