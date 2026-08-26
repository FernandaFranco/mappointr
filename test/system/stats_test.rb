require "application_system_test_case"

class StatsTest < ApplicationSystemTestCase
  test "acessa as estatísticas globais pelo menu, sem login nenhum" do
    visit root_path
    click_on "Estatísticas"

    assert_selector "h1", text: "Estatísticas globais"
    assert_selector "#stats-map-container"
    assert_text "Nenhum país selecionado ainda."
  end

  # atlantis tem 3 game_rounds nas fixtures (acerto, quase, erro): 1 de cada,
  # então o painel deve mostrar 33.3% em cada percentual e 3 pontos no mapa.
  test "clicar num país jogado no mapa carrega as estatísticas e os pontos de chute dele" do
    visit stats_path

    assert_selector "path.played-country-#{countries(:atlantis).id}"

    # Mesmo bug de ChromeDriver/CDP documentado em application_system_test_case.rb
    # (o Leaflet segue mexendo no DOM enquanto tiles/camadas chegam) pode
    # acontecer ao clicar num path também, não só no #map-container.
    retry_on_stale_node do
      first("path.played-country-#{countries(:atlantis).id}").click
      assert_text "Atlântida"
    end

    assert_text "Tentativas"
    assert_selector "div.text-2xl", exact_text: "3"
    assert_selector "div.text-2xl", exact_text: "33.3%", minimum: 3
    assert_text "4,777.3 km"

    # 1 path do país jogado (atlantis) + 3 pontos de chute desenhados depois
    # do clique — o polígono do país já é um path.leaflet-interactive
    # sozinho, então exigir pelo menos 4 prova que os pontos também
    # renderizaram. visible: :all porque o fitBounds enquadra só o polígono
    # de atlantis; o chute da fixture "erro" (do outro lado do globo, de
    # propósito) renderiza fora da área visível.
    assert_selector "path.leaflet-interactive", minimum: 4, visible: :all

    click_on "Fechar"
    assert_text "Nenhum país selecionado ainda."
  end

  test "estatísticas globais mostram o estado vazio quando não há nenhuma rodada no banco" do
    GameRound.delete_all

    visit stats_path

    assert_selector "h1", text: "Estatísticas globais"
    assert_text "Ninguém jogou nenhuma rodada ainda."
    assert_selector "a", text: "Jogar agora"
  end
end
