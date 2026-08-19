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

  private

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
