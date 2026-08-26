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

  # --- next_difficulty ---

  test "next_difficulty é medium para um usuário sem nenhuma rodada" do
    assert_equal :medium, users(:novato).next_difficulty
  end

  test "next_difficulty é medium para um usuário com menos de MIN_ROUNDS_FOR_PROGRESSION rodadas" do
    novato = users(:novato)
    # 4 rodadas, todas corretas — menos que o mínimo de 5 para sair de :medium
    create_rounds(novato, [ :correct, :correct, :correct, :correct ])

    assert_equal 4, novato.total_games
    assert_equal :medium, novato.next_difficulty
  end

  test "next_difficulty é hard quando as últimas ROUNDS_WINDOW rodadas têm >= 70% de sucesso" do
    novato = users(:novato)
    # 10 rodadas: 7 successful (correct/close) + 3 wrong = 70% success_rate
    create_rounds(novato, [ :correct, :correct, :correct, :close, :close, :close, :close, :wrong, :wrong, :wrong ])

    assert_equal :hard, novato.next_difficulty
  end

  test "next_difficulty é easy quando as últimas ROUNDS_WINDOW rodadas têm < 40% de sucesso" do
    novato = users(:novato)
    # 10 rodadas: 3 successful (correct/close) + 7 wrong = 30% success_rate
    create_rounds(novato, [ :correct, :close, :close, :wrong, :wrong, :wrong, :wrong, :wrong, :wrong, :wrong ])

    assert_equal :easy, novato.next_difficulty
  end

  test "next_difficulty é medium quando a taxa de sucesso está entre os dois limiares" do
    novato = users(:novato)
    # 10 rodadas: 5 successful (correct/close) + 5 wrong = 50% success_rate
    create_rounds(novato, [ :correct, :correct, :close, :close, :close, :wrong, :wrong, :wrong, :wrong, :wrong ])

    assert_equal :medium, novato.next_difficulty
  end

  # next_difficulty olha só para a janela de ROUNDS_WINDOW rodadas mais recentes,
  # não para a média histórica (success_percentage). Um usuário com uma sequência
  # ruim no início (que puxaria a média histórica para baixo) mas uma sequência
  # recente muito boa deve terminar em uma dificuldade melhor do que a média
  # histórica sugeriria — esse é o ponto inteiro de usar uma janela.
  test "next_difficulty usa uma janela recente, não a média histórica" do
    novato = users(:novato)

    # 6 rodadas antigas, todas erradas
    create_rounds(novato, [ :wrong, :wrong, :wrong, :wrong, :wrong, :wrong ])
    # 10 rodadas recentes, todas corretas (janela = 100% de sucesso)
    create_rounds(novato, [ :correct ] * 10)

    # Média histórica: 10 successful em 16 rodadas = 62.5%, o que sozinho
    # ficaria abaixo do limiar de :hard (70%) — mas a janela recente é 100%.
    assert_in_delta 62.5, novato.success_percentage, 0.01
    assert_equal :hard, novato.next_difficulty
  end

  # next_difficulty olha só para game_rounds.where(room_round_id: nil): jogadas
  # de sala não são um sinal válido de desempenho individual (o país da sala é
  # sorteado pela dificuldade da SALA, não pelo desempenho do jogador), então
  # devem ficar fora da janela usada para decidir a próxima dificuldade.
  test "next_difficulty ignora jogadas de sala (room_round_id presente) na sua janela" do
    novato = users(:novato)
    # 10 rodadas solo recentes, todas wrong (janela = 0% de sucesso) → :easy
    create_rounds(novato, [ :wrong ] * 10)

    assert_equal :easy, novato.next_difficulty

    # Um monte de jogadas DE SALA, todas corretas — se fossem indevidamente
    # incluídas na janela, dominariam as 10 solo e empurrariam para :hard.
    room = Room.create!(host: novato)
    room.room_players.create!(user: novato)
    10.times do |i|
      room_round = RoomRound.create!(room: room, country: countries(:atlantis), round_number: i + 1, started_at: Time.current)
      GameRound.create!(user: novato, country: countries(:atlantis), room_round: room_round,
        guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5)
    end

    assert_equal 20, novato.total_games, "as jogadas de sala devem existir e contar para total_games..."
    assert_equal :easy, novato.next_difficulty, "...mas não devem entrar na janela de next_difficulty"
  end

  # --- identidade: display_name, create_player! ---

  test "display_name presente é obrigatório" do
    user = User.new(display_name: nil)

    assert_not user.valid?
    assert_includes user.errors[:display_name], "can't be blank"
  end

  test "create_player! cria um usuário válido com apelido gerado" do
    jogador = User.create_player!

    assert jogador.persisted?
    assert_match(/\AVisitante \d+\z/, jogador.display_name)
  end

  private

  # Cria rodadas de jogo para +user+ com os resultados dados, em ordem
  # cronológica (a primeira da lista é a mais antiga). Como fixtures não
  # disparam callbacks mas game_rounds.create! dispara, escolhemos
  # coordenadas dentro/fora de atlantis para forçar o resultado desejado e
  # depois ajustamos created_at manualmente para controlar a ordenação usada
  # por next_difficulty (created_at desc).
  COORDS_FOR_RESULT = {
    correct: { lat: 5.0, lng: 5.0 },   # dentro de atlantis → distância 0
    close: { lat: 5.0, lng: 13.0 },    # ~330km da fronteira → close
    wrong: { lat: -30.0, lng: 150.0 }  # do outro lado do mundo → wrong
  }.freeze

  def create_rounds(user, results)
    base_time = 1.hour.ago
    results.each_with_index do |result, index|
      coords = COORDS_FOR_RESULT.fetch(result)
      round = user.game_rounds.create!(
        country: countries(:atlantis),
        guessed_lat: coords[:lat],
        guessed_lng: coords[:lng],
        time_seconds: 10
      )
      round.update_column(:created_at, base_time + index.seconds)
      assert_equal result.to_s, round.result, "fixture de coordenadas para #{result} não produziu o resultado esperado"
    end
  end
end
