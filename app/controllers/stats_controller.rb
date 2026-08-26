class StatsController < ApplicationController
  # GET /stats
  # Estatísticas globais por país: quantas vezes cada país já foi
  # tentado e como os chutes se distribuíram entre acerto/quase/erro.
  # Pública — não depende de current_user.
  def show
    totals = GameRound.group(:country_id).count
    corrects = GameRound.correct.group(:country_id).count
    closes = GameRound.close.group(:country_id).count
    wrongs = GameRound.wrong.group(:country_id).count
    avg_distances = GameRound.group(:country_id).average(:distance_km)

    countries = Country.where(id: totals.keys).index_by(&:id)

    @country_stats = totals.map do |country_id, total|
      {
        country: countries[country_id],
        total: total,
        correct_percentage: ((corrects[country_id] || 0).to_f / total * 100).round(1),
        close_percentage: ((closes[country_id] || 0).to_f / total * 100).round(1),
        wrong_percentage: ((wrongs[country_id] || 0).to_f / total * 100).round(1),
        avg_distance: avg_distances[country_id]&.round(1) || 0
      }
    end.sort_by { |stat| -stat[:total] }
  end
end
