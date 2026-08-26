require "application_system_test_case"

class GamesTest < ApplicationSystemTestCase
  test "jogar uma rodada solo até a página de resultado" do
    sign_in_as(users(:fernanda))

    visit new_game_path
    assert_selector "#map-container"

    click_map_and_expect "Suas estatísticas"
    assert_text "Tempo de resposta"
  end

  # atlantis já tem 3 game_rounds nas fixtures (acerto, quase, erro), então
  # a rodada de fernanda (acerto) tem outros jogadores pra comparar — mostra
  # o card de comparação e um ponto no mapa por chute já feito no país.
  test "resultado com outros jogadores no país mostra comparação e os pontos de todo mundo" do
    sign_in_as(users(:fernanda))

    visit game_path(game_rounds(:acerto))

    assert_text "Comparação com outros jogadores"
    assert_text "Cada ponto no mapa é um chute já feito por outro jogador"

    # O polígono da fronteira (L.geoJSON) já é um path.leaflet-interactive
    # sozinho, então exigir pelo menos 2 prova que os pontos (L.circleMarker,
    # mesmo seletor no renderer SVG do Leaflet) também renderizaram — as
    # fixtures acerto/quase/erro dão 3 chutes em atlantis, então
    # GameRound.guess_points tem o que desenhar.
    assert_selector "path.leaflet-interactive", minimum: 2

    # public/world_boundaries.geojson é estático (não depende do banco de
    # teste com países fictícios) — sempre tem os ~177 países de verdade, e
    # interactive: false tira essa camada do seletor acima, daí precisar de
    # um className próprio pra provar que ela também renderizou de verdade.
    # O mapa fica bem fechado nesse teste (fitBounds no país fictício +
    # pontos de chute), então só os países cujo bounding box cruza essa
    # janela pequena ficam visíveis — não os ~177 inteiros.
    assert_selector "path.world-boundary", minimum: 10
  end

  # edenia não tem game_rounds nas fixtures: esta é a primeira rodada desse
  # país, então não há nada pra comparar nem nenhum ponto de outro jogador.
  test "resultado sendo o primeiro a jogar o país não mostra comparação nem pontos de outros jogadores" do
    sign_in_as(users(:fernanda))
    primeira_rodada = GameRound.create!(user: users(:fernanda), country: countries(:edenia),
      guessed_lat: 25.0, guessed_lng: 5.0, time_seconds: 10)

    visit game_path(primeira_rodada)

    assert_text "Você é o primeiro a jogar este país!"
    assert_no_text "Comparação com outros jogadores"
    assert_no_text "Cada ponto no mapa é um chute já feito por outro jogador"
  end

  # --- primeira visita (sem sign_in_as nenhum) ---

  test "primeira visita cria um jogador automaticamente e mostra o mapa, sem login nenhum" do
    visit root_path

    assert_selector "#map-container"
    # Turbo Drive faz uma navegação de verdade aqui (hard navigation da
    # primeira visita), mas o Leaflet carrega de forma assíncrona — sem
    # esperar o placeholder sumir, o clique pode chegar antes dele ter
    # inicializado de verdade e não registrar chute nenhum.
    assert_no_text "Carregando mapa..."

    click_map_and_expect "Suas estatísticas"
  end
end
