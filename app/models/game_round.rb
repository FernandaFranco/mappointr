class GameRound < ApplicationRecord
  # Relacionamentos
  belongs_to :user
  belongs_to :country
  belongs_to :room_round, optional: true

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
  validates :room_round_id, uniqueness: { scope: :user_id }, allow_nil: true

  # Callbacks - calcula distância e resultado antes de salvar
  before_validation :calculate_distance_and_result, on: :create

  # Escopos para estatísticas
  scope :for_country, ->(country_id) { where(country_id: country_id) }
  scope :correct_guesses, -> { where(result: :correct) }
  scope :close_guesses, -> { where(result: :close) }
  scope :successful_guesses, -> { where(result: [ :correct, :close ]) }

  # Tamanho da célula do grid do mapa de calor, em graus (~111km no equador).
  # Agrupa todos os chutes já feitos num país numa grade fixa antes de mandar
  # pro navegador — isso limita a resposta a no máximo (360/cell) * (180/cell)
  # pontos, não importa quantos milhares de GameRound existam pra esse país.
  HEATMAP_CELL_SIZE = 1.0

  # Agrega todo chute já feito num país numa grade, retornando [lat, lng, peso]
  # pra alimentar o Leaflet.heat. cell_size nunca vem de input do usuário, então
  # a interpolação de string no Arel.sql abaixo é segura (não é o mesmo padrão
  # de risco das consultas PostGIS cruas em Country).
  def self.heatmap_points(country_id, cell_size: HEATMAP_CELL_SIZE)
    for_country(country_id)
      .group(Arel.sql("ROUND(guessed_lat / #{cell_size}) * #{cell_size}"))
      .group(Arel.sql("ROUND(guessed_lng / #{cell_size}) * #{cell_size}"))
      .count
      .map { |(lat, lng), weight| [ lat.to_f, lng.to_f, weight ] }
  end

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
