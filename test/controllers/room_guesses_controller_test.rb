require "test_helper"

class RoomGuessesControllerTest < ActionDispatch::IntegrationTest
  test "POST /rooms/:room_id/guesses aceita o chute no meio da rodada" do
    sala = iniciar_sala_em_andamento(jogadores: 2)
    sign_in_as users(:fernanda)

    assert_difference "GameRound.count", 1 do
      post room_guesses_path(sala), params: { lat: 5.0, lng: 5.0 }
    end

    assert_redirected_to room_path(sala)
    jogada = GameRound.last
    assert_equal users(:fernanda), jogada.user
    assert_equal sala.current_room_round, jogada.room_round
    assert_equal "correct", jogada.result
  end

  test "POST /rooms/:room_id/guesses é rejeitado depois que a rodada termina" do
    sala = iniciar_sala_em_andamento(jogadores: 2)
    rodada = sala.current_room_round
    rodada.finalize!
    sign_in_as users(:fernanda)

    assert_no_difference "GameRound.count" do
      post room_guesses_path(sala), params: { lat: 5.0, lng: 5.0 }
    end

    assert_redirected_to room_path(sala)
    assert_equal "Essa rodada já terminou.", flash[:alert]
  end

  test "POST /rooms/:room_id/guesses é rejeitado para quem não é membro da sala" do
    sala = iniciar_sala_em_andamento(jogadores: 2)
    sign_in_as users(:novato)

    assert_no_difference "GameRound.count" do
      post room_guesses_path(sala), params: { lat: 5.0, lng: 5.0 }
    end

    assert_redirected_to new_room_path
    assert_equal "Você não faz parte dessa sala.", flash[:alert]
  end

  # Regressão dos bugs #1, #2 e #3: o último chute de uma rodada dispara
  # finalize! (bug #2: ended_at precisa estar presente no mesmo objeto em
  # memória usado pelo broadcast) e depois broadcasta rooms/_results.html.erb
  # (bugs #1 e #3: current_user e render sem o prefixo "rooms/" quebravam
  # fora de uma request normal). Se qualquer um voltasse, esta request
  # levantaria uma exceção não tratada.
  test "o último chute da rodada finaliza a rodada e transmite os resultados sem levantar exceção" do
    sala = iniciar_sala_em_andamento(jogadores: 2)
    rodada = sala.current_room_round
    outro_jogador = (rodada.room.players - [ users(:fernanda) ]).first
    GameRound.create!(user: outro_jogador, country: rodada.country, room_round: rodada,
      guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5)
    sign_in_as users(:fernanda)

    post room_guesses_path(sala), params: { lat: 5.0, lng: 5.0 }

    assert_redirected_to room_path(sala)
    assert rodada.reload.finished?
    assert rodada.ended_at.present?
  end

  # validates :room_round_id, uniqueness: { scope: :user_id } — chutar duas
  # vezes na mesma rodada deve ser tratado graciosamente (flash de erro),
  # não estourar um RecordInvalid/RecordNotUnique não tratado.
  test "não é possível chutar duas vezes na mesma rodada" do
    sala = iniciar_sala_em_andamento(jogadores: 2)
    sign_in_as users(:fernanda)
    post room_guesses_path(sala), params: { lat: 5.0, lng: 5.0 }
    assert_equal 1, sala.current_room_round.reload.game_rounds.where(user: users(:fernanda)).count

    assert_no_difference "GameRound.count" do
      post room_guesses_path(sala), params: { lat: 6.0, lng: 6.0 }
    end

    assert_redirected_to room_path(sala)
    assert_match(/Erro ao registrar chute/, flash[:alert])
  end

  # Um segundo jogador (identidade separada, nunca via sign_in_as) joga como
  # um dos dois jogadores da sala — cobre o chute em si e a renderização de
  # rooms/_results.html.erb (display_name) numa rodada real, incluindo o
  # último chute que finaliza e transmite o resultado.
  test "um segundo jogador consegue chutar e finalizar a rodada sem levantar exceção" do
    sala = criar_sala(host: users(:fernanda), total_rounds: 5, difficulty: :medium)
    outro_jogador = User.create_player!
    sala.room_players.create!(user: outro_jogador)
    sign_in_as users(:fernanda)
    post start_room_path(sala)
    sala.reload

    sign_in_as outro_jogador
    post room_guesses_path(sala), params: { lat: 5.0, lng: 5.0 }
    assert_redirected_to room_path(sala)

    # Segundo (e último) chute da rodada: dispara finalize! de verdade.
    sign_in_as users(:fernanda)
    post room_guesses_path(sala), params: { lat: 5.0, lng: 5.0 }
    assert sala.current_room_round.reload.finished?

    get room_path(sala)
    assert_response :success
    assert_includes response.body, outro_jogador.display_name
  end

  private

  def criar_sala(host:, status: :waiting, **attrs)
    sala = Room.create!(host: host, status: status, **attrs)
    sala.room_players.create!(user: host)
    sala
  end

  def adicionar_jogadores(sala, count)
    Array.new(count) do |i|
      user = User.create_player!
      sala.room_players.create!(user: user)
      user
    end
  end

  # difficulty: :medium força Country.random a sortear sempre countries(:atlantis)
  # (a única fixture jogável com essa dificuldade), assim os testes podem
  # chutar coordenadas fixas e prever o resultado.
  def iniciar_sala_em_andamento(jogadores:, total_rounds: 5, difficulty: :medium)
    sala = criar_sala(host: users(:fernanda), total_rounds: total_rounds, difficulty: difficulty)
    adicionar_jogadores(sala, jogadores - 1)
    sign_in_as users(:fernanda)

    post start_room_path(sala)
    sala.reload
  end
end
