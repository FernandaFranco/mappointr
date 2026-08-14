require "test_helper"

class UserTest < ActiveSupport::TestCase
  # fernanda tem uma única rodada (fixture "acerto"): result: correct
  test "estatísticas de um usuário só com acerto exato" do
    fernanda = users(:fernanda)

    assert_equal 1, fernanda.total_games
    assert_equal 1, fernanda.correct_games
    assert_equal 0, fernanda.close_games
    assert_equal 0, fernanda.wrong_games
    assert_equal 1, fernanda.successful_games
    assert_equal 100.0, fernanda.accuracy_percentage
    assert_equal 100.0, fernanda.success_percentage
  end

  # visitante tem duas rodadas (fixtures "quase" e "erro"): close e wrong
  test "estatísticas de um usuário com quase acerto e erro" do
    visitante = users(:visitante)

    assert_equal 2, visitante.total_games
    assert_equal 0, visitante.correct_games
    assert_equal 1, visitante.close_games
    assert_equal 1, visitante.wrong_games
    assert_equal 1, visitante.successful_games
    assert_equal 0.0, visitante.accuracy_percentage
    assert_equal 50.0, visitante.success_percentage
  end

  # novato não tem nenhuma rodada — cobre o guard de divisão por zero
  test "porcentagens de um usuário sem nenhuma rodada não dividem por zero" do
    novato = users(:novato)

    assert_equal 0, novato.total_games
    assert_equal 0, novato.correct_games
    assert_equal 0, novato.close_games
    assert_equal 0, novato.wrong_games
    assert_equal 0, novato.successful_games
    assert_equal 0, novato.accuracy_percentage
    assert_equal 0, novato.success_percentage
  end
end
