class Country < ApplicationRecord
  # Relacionamentos
  has_many :game_rounds, dependent: :restrict_with_error

  # Enum para dificuldade (0 = easy, 1 = medium, 2 = hard)
  enum :difficulty, { easy: 0, medium: 1, hard: 2 }, default: :medium

  # Validações
  validates :name, presence: true, uniqueness: true
  validates :name_pt, presence: true
  validates :boundary, presence: true

  # Escopos
  scope :playable, -> { where(excluded: false) }

  # Sorteia um país aleatório entre os jogáveis
  # Se difficulty for informado, prioriza países daquela dificuldade;
  # se não houver nenhum jogável naquela dificuldade, cai de volta para
  # qualquer país jogável (nunca retorna um excluded, nunca sorteia de um
  # escopo vazio)
  def self.random(difficulty: nil)
    scope = playable
    if difficulty.present?
      tiered = scope.where(difficulty: difficulty)
      scope = tiered if tiered.exists?
    end
    count = scope.count
    return nil if count.zero?
    scope.offset(rand(count)).first
  end

  # Calcula a distância em km de um ponto até a fronteira do país
  # Retorna 0 se o ponto estiver dentro do país
  def distance_from(lat, lng)
    # ST_Distance retorna metros quando usamos geography
    # Dividimos por 1000 para ter km
    sql = self.class.sanitize_sql_array([ <<~SQL, lng: lng, lat: lat, id: id ])
      SELECT ST_Distance(
        boundary::geography,
        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
      ) / 1000.0 AS distance_km
      FROM countries
      WHERE id = :id
    SQL
    result = self.class.connection.select_value(sql)
    result.to_f.round(1)
  end

  # Verifica se um ponto está dentro do país
  # Nota: ST_Contains requer geometry (não geography)
  # Usamos cast explícito para geometry
  def contains?(lat, lng)
    sql = self.class.sanitize_sql_array([ <<~SQL, lng: lng, lat: lat, id: id ])
      SELECT ST_Contains(
        boundary::geometry,
        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)
      )
      FROM countries
      WHERE id = :id
    SQL
    result = self.class.connection.select_value(sql)
    result == true || result == "t"
  end

  # Retorna o centroide (ponto central) do país
  def centroid
    result = self.class.connection.select_one(<<~SQL)
      SELECT
        ST_Y(ST_Centroid(boundary::geometry)) AS lat,
        ST_X(ST_Centroid(boundary::geometry)) AS lng
      FROM countries
      WHERE id = #{id}
    SQL
    return nil unless result
    { lat: result["lat"].to_f.round(4), lng: result["lng"].to_f.round(4) }
  end

  # Retorna o GeoJSON da fronteira (para desenhar no mapa)
  def boundary_geojson
    self.class.connection.select_value(<<~SQL)
      SELECT ST_AsGeoJSON(boundary::geometry, 4)
      FROM countries
      WHERE id = #{id}
    SQL
  end

  # Retorna o ponto mais próximo na fronteira a partir de um ponto dado
  def nearest_border_point(lat, lng)
    sql = self.class.sanitize_sql_array([ <<~SQL, lng: lng, lat: lat, id: id ])
      SELECT
        ST_Y(ST_ClosestPoint(boundary::geometry, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326))) AS lat,
        ST_X(ST_ClosestPoint(boundary::geometry, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326))) AS lng
      FROM countries
      WHERE id = :id
    SQL
    result = self.class.connection.select_one(sql)
    return nil unless result
    { lat: result["lat"].to_f.round(4), lng: result["lng"].to_f.round(4) }
  end
end
