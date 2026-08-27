require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  # --- GET /stats ---

  test "GET /stats é pública, sem precisar de sign_in_as" do
    get stats_path

    assert_response :success
  end

  # atlantis tem 3 game_rounds nas fixtures (acerto, quase, erro); edenia não
  # tem nenhum — os dois devem aparecer, com o boundary embutido pro mapa
  # desenhar o polígono clicável de cada um (todo país é clicável, jogado
  # ou não).
  test "GET /stats inclui todos os países, jogados ou não, com o boundary embutido" do
    get stats_path

    assert_response :success
    all_countries = extract_countries
    country_ids = all_countries.map { |c| c["id"] }
    assert_includes country_ids, countries(:atlantis).id
    assert_includes country_ids, countries(:edenia).id

    atlantis_entry = all_countries.find { |c| c["id"] == countries(:atlantis).id }
    assert_equal "Atlântida", atlantis_entry["name_pt"]
    assert atlantis_entry["boundary"].present?
    assert JSON.parse(atlantis_entry["boundary"]).present?, "boundary deveria ser GeoJSON válido"
  end

  test "GET /stats mostra o mapa mesmo sem nenhuma jogada no banco" do
    GameRound.delete_all

    get stats_path

    assert_response :success
    assert_not_empty extract_countries
  end

  # --- GET /stats/:country_id ---

  # atlantis tem 3 game_rounds nas fixtures: acerto (correct), quase (close),
  # erro (wrong) — 1 de cada, então cada percentual é 33.3% e a distância
  # média é (0 + 332 + 14000) / 3 = 4777.3.
  test "GET /stats/:country_id mostra as estatísticas e os pontos de chute do país" do
    get country_stats_path(countries(:atlantis))

    assert_response :success
    assert_includes response.body, "Atlântida"
    assert_equal "3", stat_value("Tentativas")
    assert_equal "33.3%", stat_value("% acerto")
    assert_equal "33.3%", stat_value("% quase")
    assert_equal "33.3%", stat_value("% erro")
    assert_equal "4,777.3 km", stat_value("Distância média")
    assert_equal 3, extract_guess_points.length
  end

  test "GET /stats/:country_id de um país sem nenhuma jogada mostra a mensagem de ausência de dados" do
    get country_stats_path(countries(:edenia))

    assert_response :success
    assert_includes response.body, "Esse país ainda não foi jogado."
    assert_equal [], extract_guess_points
  end

  test "GET /stats/:country_id de um país inexistente retorna 404" do
    get country_stats_path(999999)

    assert_response :not_found
  end

  private

  def extract_countries
    doc = Nokogiri::HTML5.parse(response.body)
    map_div = doc.at_css("#stats-map-container")
    JSON.parse(map_div["data-stats-map-countries-value"])
  end

  def extract_guess_points
    json = response.body[/data-country-guess-points-points-value="([^"]*)"/, 1]
    assert json.present?, "esperava encontrar data-country-guess-points-points-value na resposta"
    JSON.parse(CGI.unescapeHTML(json))
  end

  def stat_value(label)
    doc = Nokogiri::HTML5.parse(response.body)
    label_node = doc.css("div.text-sm").find { |node| node.text.strip == label }
    assert label_node, "não encontrei um card com o rótulo #{label.inspect}"

    label_node.parent.css("div.text-2xl").first.text.strip
  end
end
