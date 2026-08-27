class StatsController < ApplicationController
  # GET /stats
  # Mapa-múndi interativo: todo país aparece clicável, jogado ou não.
  # Escolher um deles carrega suas estatísticas + pontos de chute via GET
  # /stats/:id (#country) dentro de um turbo-frame, sem recarregar a página.
  # Pública — não depende de current_user.
  def show
    @countries = Country.pluck(:id, :name_pt, Arel.sql("ST_AsGeoJSON(boundary::geometry, 4)"))
      .map { |id, name_pt, boundary| { id: id, name_pt: name_pt, boundary: boundary } }
  end

  # GET /stats/:country_id
  # Estatísticas + pontos de chute de um país só — carregado dentro do
  # turbo-frame "country-stats-panel" quando o jogador clica nele no mapa.
  def country
    @country = Country.find(params[:country_id])
    @stat = country_stat(@country.id)
    @guess_points = GameRound.guess_points(@country.id)
  end

  private

  def country_stat(country_id)
    rounds = GameRound.for_country(country_id)
    total = rounds.count
    return nil if total.zero?

    {
      total: total,
      correct_percentage: (rounds.correct.count.to_f / total * 100).round(1),
      close_percentage: (rounds.close.count.to_f / total * 100).round(1),
      wrong_percentage: (rounds.wrong.count.to_f / total * 100).round(1),
      avg_distance: rounds.average(:distance_km)&.round(1) || 0
    }
  end
end
