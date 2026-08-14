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
end
