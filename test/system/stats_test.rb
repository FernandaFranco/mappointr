require "application_system_test_case"

class StatsTest < ApplicationSystemTestCase
  test "acessa as estatísticas globais pelo menu, sem login nenhum" do
    visit root_path
    click_on "Estatísticas"

    assert_selector "h1", text: "Estatísticas globais"
    assert_selector "#stats-map-container"
    assert_text "Nenhum país selecionado ainda."
    # Todo país é clicável, jogado ou não — draconia não tem game_rounds
    # nenhum nas fixtures, mas o polígono dele deve estar no mapa mesmo assim.
    assert_selector "path.country-outline-#{countries(:draconia).id}"
  end

  # atlantis tem 3 game_rounds nas fixtures (acerto, quase, erro): 1 de cada,
  # então o painel deve mostrar 33.3% em cada percentual e 3 pontos no mapa.
  test "clicar num país jogado no mapa carrega as estatísticas e os pontos de chute dele" do
    visit stats_path

    assert_selector "path.country-outline-#{countries(:atlantis).id}"

    # Mesmo bug de ChromeDriver/CDP documentado em application_system_test_case.rb
    # (o Leaflet segue mexendo no DOM enquanto tiles/camadas chegam) pode
    # acontecer ao clicar num path também, não só no #map-container.
    retry_on_stale_node do
      first("path.country-outline-#{countries(:atlantis).id}").click
      assert_text "Atlântida"
    end

    assert_text "Tentativas"
    assert_selector "div.text-2xl", exact_text: "3"
    assert_selector "div.text-2xl", exact_text: "33.3%", minimum: 3
    assert_text "4,777.3 km"

    # 4 países cadastrados nas fixtures (todos clicáveis, jogado ou não) + 3
    # pontos de chute desenhados depois do clique. visible: :all porque o
    # fitBounds enquadra só os 4 países fixture; o chute da fixture "erro"
    # (do outro lado do globo, de propósito) renderiza fora da área visível.
    assert_selector "path.leaflet-interactive", minimum: 7, visible: :all

    click_on "Fechar"
    assert_text "Nenhum país selecionado ainda."
  end

  # edenia não tem nenhum game_round nas fixtures — clicar nele prova que um
  # país sem nenhuma jogada também é clicável, e mostra a mensagem certa em
  # vez de estatísticas.
  test "clicar num país nunca jogado no mapa mostra que ele ainda não foi jogado" do
    visit stats_path

    retry_on_stale_node do
      first("path.country-outline-#{countries(:edenia).id}").click
      assert_text "Edênia"
    end

    assert_text "Esse país ainda não foi jogado."
    assert_no_text "Tentativas"
  end

  # Clicar num segundo país deve trocar o painel (e, por trás, tirar o
  # destaque do país anterior) em vez de acumular os dois.
  test "clicar num país depois de outro troca o painel para o novo país" do
    visit stats_path

    retry_on_stale_node do
      first("path.country-outline-#{countries(:atlantis).id}").click
      assert_text "Atlântida"
    end

    retry_on_stale_node do
      first("path.country-outline-#{countries(:edenia).id}").click
      assert_text "Edênia"
    end

    assert_no_text "Atlântida"
    assert_text "Esse país ainda não foi jogado."
  end

  test "o mapa mostra os países clicáveis mesmo sem nenhuma jogada no banco" do
    GameRound.delete_all

    visit stats_path

    assert_selector "h1", text: "Estatísticas globais"
    assert_selector "path.country-outline-#{countries(:atlantis).id}"
  end
end
