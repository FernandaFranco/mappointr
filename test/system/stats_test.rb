require "application_system_test_case"

class StatsTest < ApplicationSystemTestCase
  test "usuário com rodadas jogadas vê suas estatísticas ao clicar no menu" do
    sign_in_via_ui(users(:fernanda))

    click_on "Minhas estatísticas"

    assert_selector "h1", text: "Minhas estatísticas"
    assert_text "Rodadas jogadas"
    assert_text "Acertos exatos"
    assert_no_text "Você ainda não jogou nenhuma rodada."
  end

  test "usuário sem rodadas jogadas vê o estado vazio com convite para jogar" do
    sign_in_via_ui(users(:novato))

    click_on "Minhas estatísticas"

    assert_selector "h1", text: "Minhas estatísticas"
    assert_text "Você ainda não jogou nenhuma rodada."
    assert_selector "a", text: "Jogar agora"
  end

  private

  def sign_in_via_ui(user)
    visit new_user_session_path

    fill_in "E-mail", with: user.email
    fill_in "Senha", with: "password123"
    click_on "Entrar"
  end
end
