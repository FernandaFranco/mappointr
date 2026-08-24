require "test_helper"

class GuestClaimsControllerTest < ActionDispatch::IntegrationTest
  test "GET /guest_claim/new sem login redireciona para o sign in" do
    get new_guest_claim_path

    assert_redirected_to new_user_session_path
  end

  test "GET /guest_claim/new logado como usuário real redireciona pra raiz" do
    sign_in users(:fernanda)

    get new_guest_claim_path

    assert_redirected_to root_path
  end

  test "GET /guest_claim/new logado como visitante mostra o formulário" do
    sign_in User.create_guest!

    get new_guest_claim_path

    assert_response :success
  end

  test "POST /guest_claim transforma o visitante numa conta de verdade mantendo o id e o histórico" do
    visitante = User.create_guest!
    sign_in visitante
    rodada = GameRound.create!(user: visitante, country: countries(:atlantis),
      guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5)

    post guest_claim_path, params: {
      user: { email: "novaconta@example.com", password: "senha12345", password_confirmation: "senha12345" }
    }

    assert_redirected_to root_path
    visitante.reload

    assert_equal "novaconta@example.com", visitante.email
    assert_not visitante.guest?
    assert_equal "novaconta@example.com", visitante.display_name
    assert_equal visitante, rodada.reload.user, "a jogada de antes de reivindicar a conta deveria continuar existindo"
  end

  # Regressão: trocar a senha muda authenticatable_salt, e o Warden desloga
  # sozinho qualquer sessão cujo salt não bata mais no request seguinte —
  # sem bypass_sign_in em GuestClaimsController#create, o usuário via a
  # mensagem de sucesso mas já estava deslogado ao carregar a página seguinte.
  test "POST /guest_claim mantém o usuário logado depois de trocar a senha" do
    sign_in User.create_guest!

    post guest_claim_path, params: {
      user: { email: "novaconta@example.com", password: "senha12345", password_confirmation: "senha12345" }
    }
    follow_redirect!

    assert_response :success
    assert_not_includes response.body, "You need to sign in or sign up before continuing."

    get new_game_path
    assert_response :success, "a sessão deveria continuar autenticada depois de reivindicar a conta"
  end

  test "POST /guest_claim com senhas que não conferem não altera a conta" do
    visitante = User.create_guest!
    sign_in visitante
    email_original = visitante.email

    post guest_claim_path, params: {
      user: { email: "novaconta@example.com", password: "senha12345", password_confirmation: "outrasenha" }
    }

    assert_response :unprocessable_entity
    visitante.reload

    assert visitante.guest?
    assert_equal email_original, visitante.email
  end

  test "POST /guest_claim sem estar logado como visitante redireciona pra raiz" do
    sign_in users(:fernanda)

    post guest_claim_path, params: {
      user: { email: "novaconta@example.com", password: "senha12345", password_confirmation: "senha12345" }
    }

    assert_redirected_to root_path
    assert_not_equal "novaconta@example.com", users(:fernanda).reload.email
  end
end
