require "application_system_test_case"

class StatsTest < ApplicationSystemTestCase
  test "acessa as estatísticas globais pelo menu, sem login nenhum" do
    visit root_path
    click_on "Estatísticas"

    assert_selector "h1", text: "Estatísticas globais"
    # atlantis tem 3 game_rounds nas fixtures (acerto, quase, erro)
    assert_text countries(:atlantis).name_pt
    assert_no_text "Ninguém jogou nenhuma rodada ainda."
  end

  test "estatísticas globais mostram o estado vazio quando não há nenhuma rodada no banco" do
    GameRound.delete_all

    visit stats_path

    assert_selector "h1", text: "Estatísticas globais"
    assert_text "Ninguém jogou nenhuma rodada ainda."
    assert_selector "a", text: "Jogar agora"
  end
end
