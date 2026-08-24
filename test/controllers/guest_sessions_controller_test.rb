require "test_helper"

class GuestSessionsControllerTest < ActionDispatch::IntegrationTest
  test "POST /guest_session cria um usuário convidado e loga com ele" do
    assert_difference "User.guest.count", 1 do
      post guest_session_path
    end

    assert_redirected_to root_path

    # Loga de verdade — uma rota que exige login deve funcionar em seguida.
    get new_game_path
    assert_response :success
  end

  test "POST /guest_session reaproveita o mesmo convidado numa segunda chamada na mesma sessão" do
    post guest_session_path
    primeiro_id = User.guest.order(:created_at).last.id

    assert_no_difference "User.guest.count" do
      post guest_session_path
    end

    segundo_id = User.guest.order(:created_at).last.id
    assert_equal primeiro_id, segundo_id
  end

  test "POST /guest_session ignora um current_guest_user_id de sessão que já não existe mais" do
    post guest_session_path
    primeiro_id = User.guest.order(:created_at).last.id
    User.find(primeiro_id).destroy

    assert_difference "User.guest.count", 1 do
      post guest_session_path
    end
  end
end
