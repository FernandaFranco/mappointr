class GameRound < ApplicationRecord
  # Relacionamentos
  belongs_to :user
  belongs_to :country

  # Enum para resultado da jogada
  # correct: chute dentro do país (distância = 0)
  # close: chute até 500km da fronteira ("Quase!")
  # wrong: chute a mais de 500km
  enum :result, { correct: 0, close: 1, wrong: 2 }, default: :wrong

  # Threshold para considerar "quase" (em km)
  CLOSE_THRESHOLD_KM = 500

  # Validações
  validates :guessed_lat, presence: true,
            numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :guessed_lng, presence: true,
            numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :time_seconds, presence: true, numericality: { greater_than: 0 }

  # Callbacks - calcula distância e resultado antes de salvar
  before_validation :calculate_distance_and_result, on: :create

  # Escopos para estatísticas
  scope :for_country, ->(country_id) { where(country_id: country_id) }
  scope :correct_guesses, -> { where(result: :correct) }
  scope :close_guesses, -> { where(result: :close) }
  scope :successful_guesses, -> { where(result: [ :correct, :close ]) }

  # Mensagem de feedback em português
  def result_message
    case result
    when "correct"
      "Acertou!"
    when "close"
      "Quase! Você chegou perto."
    when "wrong"
      "Errou!"
    end
  end

  # Verifica se foi um sucesso (acertou ou chegou perto)
  def success?
    correct? || close?
  end

  private

  def calculate_distance_and_result
    return unless country && guessed_lat && guessed_lng

    # Calcula distância usando PostGIS
    # Usamos round (não to_i) para não truncar chutes fora da fronteira para 0:
    # um chute a 557m de distância deve arredondar para 1km, não para "dentro" do país.
    self.distance_km = country.distance_from(guessed_lat, guessed_lng).round

    # Determina o resultado baseado na distância
    self.result = if distance_km == 0
                    :correct   # Dentro do país
    elsif distance_km <= CLOSE_THRESHOLD_KM
                    :close     # Até 500km da fronteira
    else
                    :wrong     # Mais de 500km
    end
  end
end
