require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  test "GET /stats sem estar logado redireciona para a tela de login" do
    get stats_path

    assert_redirected_to new_user_session_path
  end

  test "GET /stats logado mostra as estatísticas de um usuário só com acerto exato" do
    sign_in users(:fernanda)

    get stats_path

    assert_response :success
    assert_equal "1", stat_value("Rodadas jogadas")
    assert_equal "1", stat_value("Acertos exatos")
    assert_equal "0", stat_value("Quase acertos")
    assert_equal "0", stat_value("Erros")
    assert_equal "100.0%", stat_value("Taxa de acerto exato")
    assert_equal "100.0%", stat_value("Taxa de sucesso")
  end

  test "GET /stats logado mostra as estatísticas de um usuário com quase acerto e erro" do
    sign_in users(:visitante)

    get stats_path

    assert_response :success
    assert_equal "2", stat_value("Rodadas jogadas")
    assert_equal "0", stat_value("Acertos exatos")
    assert_equal "1", stat_value("Quase acertos")
    assert_equal "1", stat_value("Erros")
    assert_equal "0.0%", stat_value("Taxa de acerto exato")
    assert_equal "50.0%", stat_value("Taxa de sucesso")
  end

  test "GET /stats logado mostra o estado vazio para usuário sem rodadas" do
    sign_in users(:novato)

    get stats_path

    assert_response :success
    assert_match "Você ainda não jogou nenhuma rodada.", response.body
    assert_select "a[href=?]", new_game_path, text: "Jogar agora"
  end

  private

  # Extrai o valor numérico de um card de estatística a partir do seu rótulo,
  # navegando pela estrutura real da view em vez de casar strings no HTML bruto.
  def stat_value(label)
    doc = Nokogiri::HTML5.parse(response.body)
    label_node = doc.css("div.text-sm").find { |node| node.text.strip == label }
    assert label_node, "não encontrei um card com o rótulo #{label.inspect}"

    label_node.parent.css("div.text-2xl").first.text.strip
  end
end
