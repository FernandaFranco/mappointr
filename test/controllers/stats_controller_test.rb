require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  test "GET /stats é pública, sem precisar de sign_in_as" do
    get stats_path

    assert_response :success
  end

  # atlantis tem 3 game_rounds nas fixtures: acerto (correct), quase (close),
  # erro (wrong) — 1 de cada, então cada percentual é 33.3% e a distância
  # média é (0 + 332 + 14000) / 3 = 4777.3.
  test "GET /stats mostra o agregado por país" do
    get stats_path

    assert_response :success
    row = country_row("Atlântida")
    assert_equal "3", row_cell(row, 1)
    assert_equal "33.3%", row_cell(row, 2)
    assert_equal "33.3%", row_cell(row, 3)
    assert_equal "33.3%", row_cell(row, 4)
    assert_equal "4,777.3 km", row_cell(row, 5)
  end

  test "GET /stats não lista país sem nenhuma jogada" do
    get stats_path

    assert_response :success
    assert_nil country_row("Edênia", allow_missing: true)
  end

  test "GET /stats mostra o estado vazio quando não há nenhuma jogada no banco" do
    GameRound.delete_all

    get stats_path

    assert_response :success
    assert_match "Ninguém jogou nenhuma rodada ainda.", response.body
    assert_select "a[href=?]", new_game_path, text: "Jogar agora"
  end

  private

  def country_row(name_pt, allow_missing: false)
    doc = Nokogiri::HTML5.parse(response.body)
    row = doc.css("tbody tr").find { |tr| tr.at_css("td")&.text&.strip == name_pt }
    assert row, "não encontrei uma linha para #{name_pt.inspect}" unless allow_missing
    row
  end

  def row_cell(row, index)
    row.css("td")[index].text.strip
  end
end
