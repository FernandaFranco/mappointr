require "application_system_test_case"

class GamesTest < ApplicationSystemTestCase
  test "jogar uma rodada solo até a página de resultado" do
    sign_in_via_ui(users(:fernanda))

    visit new_game_path
    assert_selector "#map-container"

    find("#map-container").click

    assert_text "Suas estatísticas"
    assert_text "Tempo de resposta"
  end

  # atlantis já tem 3 game_rounds nas fixtures (acerto, quase, erro), então
  # a rodada de fernanda (acerto) tem outros jogadores pra comparar — mostra
  # o card de comparação e o mapa de calor embutido no mapa de resultado,
  # com o canvas real do Leaflet.heat.
  test "resultado com outros jogadores no país mostra comparação e mapa de calor" do
    sign_in_via_ui(users(:fernanda))

    visit game_path(game_rounds(:acerto))

    assert_text "Comparação com outros jogadores"
    assert_text "O mapa de calor mostra onde todo mundo já chutou"
    assert_selector "canvas.leaflet-heatmap-layer"
  end

  # edenia não tem game_rounds nas fixtures: esta é a primeira rodada desse
  # país, então não há nada pra comparar nem agregar no mapa de calor.
  test "resultado sendo o primeiro a jogar o país não mostra comparação nem mapa de calor" do
    sign_in_via_ui(users(:fernanda))
    primeira_rodada = GameRound.create!(user: users(:fernanda), country: countries(:edenia),
      guessed_lat: 25.0, guessed_lng: 5.0, time_seconds: 10)

    visit game_path(primeira_rodada)

    assert_text "Você é o primeiro a jogar este país!"
    assert_no_text "Comparação com outros jogadores"
    assert_no_selector "canvas.leaflet-heatmap-layer"
  end

  private

  def sign_in_via_ui(user)
    visit new_user_session_path

    fill_in "E-mail", with: user.email
    fill_in "Senha", with: "password123"
    click_on "Entrar"

    # Devise renderiza o form de sign in via Turbo Drive (fetch assíncrono),
    # então click_on pode devolver o controle antes do cookie de sessão estar
    # de fato gravado. Sem esperar por algo que só aparece autenticado, um
    # `visit` logo em seguida corre risco de pegar o navegador ainda
    # deslogado — essa asserção força o Capybara a esperar o estado real.
    assert_text "Sair"
  end
end
