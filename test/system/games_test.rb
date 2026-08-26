require "application_system_test_case"

class GamesTest < ApplicationSystemTestCase
  test "jogar uma rodada solo até a página de resultado" do
    sign_in_via_ui(users(:fernanda))

    visit new_game_path
    assert_selector "#map-container"

    click_map_and_expect "Suas estatísticas"
    assert_text "Tempo de resposta"
  end

  # atlantis já tem 3 game_rounds nas fixtures (acerto, quase, erro), então
  # a rodada de fernanda (acerto) tem outros jogadores pra comparar — mostra
  # o card de comparação e um ponto no mapa por chute já feito no país.
  test "resultado com outros jogadores no país mostra comparação e os pontos de todo mundo" do
    sign_in_via_ui(users(:fernanda))

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
    sign_in_via_ui(users(:fernanda))
    primeira_rodada = GameRound.create!(user: users(:fernanda), country: countries(:edenia),
      guessed_lat: 25.0, guessed_lng: 5.0, time_seconds: 10)

    visit game_path(primeira_rodada)

    assert_text "Você é o primeiro a jogar este país!"
    assert_no_text "Comparação com outros jogadores"
    assert_no_text "Cada ponto no mapa é um chute já feito por outro jogador"
  end

  # --- visitante (sem cadastro) ---

  test "visitante consegue jogar sem cadastro clicando em Jogar sem cadastro" do
    visit new_user_session_path
    click_on "Jogar sem cadastro"
    assert_text "Sair" # mesma sincronização do sign_in_via_ui — ver comentário lá

    assert_selector "#map-container"
    # "Jogar sem cadastro" redireciona via Turbo (sem hard navigation) —
    # sem esperar o placeholder sumir, o clique pode chegar antes do Leaflet
    # ter inicializado de verdade e não registrar chute nenhum.
    assert_no_text "Carregando mapa..."

    click_map_and_expect "Suas estatísticas"
  end

  test "visitante consegue reivindicar a conta como uma conta de verdade e mantém o histórico" do
    visit new_user_session_path
    click_on "Jogar sem cadastro"
    assert_text "Sair"

    assert_no_text "Carregando mapa..."
    click_map_and_expect "Suas estatísticas"

    click_on "Criar conta"
    assert_selector "h2", text: "Criar conta"

    fill_in "E-mail", with: "visitante_convertido@example.com"
    fill_in "Senha", with: "senha12345"
    fill_in "Confirmar senha", with: "senha12345"
    # click_on casaria com o link "Criar conta" do nav (ainda visível — o
    # usuário só deixa de ser guest depois deste submit) e com o botão do
    # form. click_button restringe a elementos de botão só.
    click_button "Criar conta"

    assert_text "Conta criada! Seu histórico de jogo foi mantido."
    assert_text "visitante_convertido@example.com"
    assert_no_text "Visitante "

    # O redirect pós-claim cai de novo em games#new (um país novo sorteado),
    # que inicializa o Leaflet e ainda pode estar mexendo no DOM (carregando
    # tiles) quando o próximo clique dispara — mesma corrida de "Node with
    # given id does not belong to the document" já vista em outros lugares
    # deste arquivo. Espera o placeholder sumir antes de clicar em qualquer
    # coisa, como já se faz em todo outro ponto que chega nessa página.
    assert_no_text "Carregando mapa..."

    click_on "Minhas estatísticas"
    assert_no_text "Você ainda não jogou nenhuma rodada."
    assert_text "Rodadas jogadas" # confirma que a rodada de antes de reivindicar a conta não sumiu
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
