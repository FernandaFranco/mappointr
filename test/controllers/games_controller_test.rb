require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "GET /play/new sem login redireciona para o sign in" do
    get new_game_path

    assert_redirected_to new_user_session_path
  end

  test "GET /play/new logado sorteia um país jogável e guarda na sessão" do
    sign_in users(:fernanda)
    playable_ids = [ countries(:atlantis).id, countries(:edenia).id, countries(:draconia).id ]

    5.times do
      get new_game_path

      assert_response :success
      assert_includes playable_ids, session[:current_country_id]
      assert_not_equal countries(:pacifica).id, session[:current_country_id]
    end
  end

  test "GET /play/new com tabela de países vazia renderiza a página de indisponibilidade" do
    sign_in users(:fernanda)
    # game_rounds tem uma foreign key para countries — precisa ir embora primeiro
    GameRound.delete_all
    Country.delete_all

    get new_game_path

    assert_response :service_unavailable
    assert_includes response.body, "Nenhum país disponível para jogar no momento."
    assert_nil session[:current_country_id]
  end

  # --- GET /play/:id (#show) ---

  test "GET /play/:id sem login redireciona para o sign in" do
    get game_path(game_rounds(:acerto))

    assert_redirected_to new_user_session_path
  end

  # A fixture atlantis já tem 3 game_rounds (acerto, quase, erro), então
  # total_attempts > 1 — mostra comparação com outros jogadores e os pontos
  # de todo mundo que já chutou embutidos no mapa de resultado (mesmo
  # data-controller="result-map"), com data-result-map-guess-points-value
  # preenchido.
  test "GET /play/:id com outros jogadores no mesmo país mostra comparação e os pontos de todo mundo" do
    sign_in users(:fernanda)

    get game_path(game_rounds(:acerto))

    assert_response :success
    assert_includes response.body, "Comparação com outros jogadores"
    assert_includes response.body, "Cada ponto no mapa é um chute já feito por outro jogador"
    assert_not_includes response.body, 'data-result-map-guess-points-value="[]"'
    assert_not_includes response.body, "Você é o primeiro a jogar este país!"
  end

  # edenia não tem nenhum game_round nas fixtures: a rodada criada abaixo é a
  # primeira. total_attempts == 1 → sem comparação, sem pontos de outros jogadores.
  test "GET /play/:id sendo o primeiro a jogar o país não mostra comparação nem pontos de outros jogadores" do
    sign_in users(:fernanda)
    primeira_rodada = GameRound.create!(user: users(:fernanda), country: countries(:edenia),
      guessed_lat: 25.0, guessed_lng: 5.0, time_seconds: 10)

    get game_path(primeira_rodada)

    assert_response :success
    assert_includes response.body, "Você é o primeiro a jogar este país!"
    assert_not_includes response.body, "Comparação com outros jogadores"
    assert_includes response.body, 'data-result-map-guess-points-value="[]"'
    assert_not_includes response.body, "Cada ponto no mapa é um chute já feito por outro jogador"
  end

  test "GET /play/:id de uma rodada de outro usuário retorna 404" do
    sign_in users(:visitante)

    get game_path(game_rounds(:acerto)) # pertence a fernanda

    assert_response :not_found
  end

  # --- fluxo completo como visitante (sem cadastro) ---

  test "um usuário convidado consegue jogar uma rodada solo do início ao fim" do
    sign_in User.create_guest!

    get new_game_path
    assert_response :success
    country_id = session[:current_country_id]

    post games_path, params: { lat: 5.0, lng: 5.0 }
    game_round = GameRound.find_by(country_id: country_id, user: current_guest)
    assert_not_nil game_round

    get game_path(game_round)
    assert_response :success
  end

  private

  def current_guest
    User.guest.order(:created_at).last
  end
end
