require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  # --- new ---

  test "GET /rooms/new sem login redireciona para o sign in" do
    get new_room_path

    assert_redirected_to new_user_session_path
  end

  # --- create ---

  test "POST /rooms cria a sala e o host entra automaticamente como jogador" do
    sign_in users(:fernanda)

    assert_difference [ "Room.count", "RoomPlayer.count" ], 1 do
      post rooms_path, params: { room: { total_rounds: 5, round_duration_seconds: 45 } }
    end

    room = Room.last
    assert_redirected_to room_path(room)
    assert_equal users(:fernanda), room.host
    assert room.room_players.exists?(user: users(:fernanda))
  end

  test "POST /rooms com parâmetros inválidos não cria a sala e renderiza o formulário" do
    sign_in users(:fernanda)

    assert_no_difference "Room.count" do
      post rooms_path, params: { room: { total_rounds: 0, round_duration_seconds: 45 } }
    end

    assert_response :unprocessable_entity
  end

  # --- join ---

  test "POST /rooms/join com código válido entra na sala" do
    sala = criar_sala(host: users(:fernanda))
    sign_in users(:visitante)

    assert_difference "RoomPlayer.count", 1 do
      post join_room_path, params: { code: sala.code }
    end

    assert_redirected_to room_path(sala)
    assert sala.room_players.exists?(user: users(:visitante))
  end

  test "POST /rooms/join aceita o código em minúsculas" do
    sala = criar_sala(host: users(:fernanda))
    sign_in users(:visitante)

    post join_room_path, params: { code: sala.code.downcase }

    assert_redirected_to room_path(sala)
    assert sala.room_players.exists?(user: users(:visitante))
  end

  test "POST /rooms/join quando já é membro apenas redireciona, sem duplicar" do
    sala = criar_sala(host: users(:fernanda))
    sign_in users(:fernanda)

    assert_no_difference "RoomPlayer.count" do
      post join_room_path, params: { code: sala.code }
    end

    assert_redirected_to room_path(sala)
  end

  test "POST /rooms/join com código inexistente redireciona com alerta" do
    sign_in users(:visitante)

    post join_room_path, params: { code: "ZZZZZZ" }

    assert_redirected_to new_room_path
    assert_equal "Código não encontrado.", flash[:alert]
  end

  test "POST /rooms/join numa sala que já começou é rejeitado" do
    sala = criar_sala(host: users(:fernanda), status: :in_progress)
    sign_in users(:visitante)

    assert_no_difference "RoomPlayer.count" do
      post join_room_path, params: { code: sala.code }
    end

    assert_redirected_to new_room_path
    assert_equal "Essa sala já começou ou terminou.", flash[:alert]
  end

  test "POST /rooms/join numa sala cheia é rejeitado" do
    sala = criar_sala(host: users(:fernanda))
    adicionar_jogadores(sala, Room::MAX_PLAYERS - 1) # host já ocupa 1 vaga
    assert sala.reload.full?
    sign_in users(:visitante)

    assert_no_difference "RoomPlayer.count" do
      post join_room_path, params: { code: sala.code }
    end

    assert_redirected_to new_room_path
    assert_equal "Essa sala está cheia.", flash[:alert]
  end

  # --- show ---

  test "GET /rooms/:id só é acessível para membros da sala" do
    sala = criar_sala(host: users(:fernanda))
    sign_in users(:visitante)

    get room_path(sala)

    assert_redirected_to new_room_path
    assert_equal "Você não faz parte dessa sala.", flash[:alert]
  end

  test "GET /rooms/:id expira automaticamente uma sala parada há mais de STALE_AFTER" do
    sala = criar_sala(host: users(:fernanda))
    sign_in users(:fernanda)

    travel Room::STALE_AFTER + 1.minute do
      get room_path(sala)
    end

    assert_response :success
    assert_equal "expired", sala.reload.status
    assert_includes response.body, "Essa sala expirou por inatividade."
  end

  test "GET /rooms/:id de uma sala fresca não a expira" do
    sala = criar_sala(host: users(:fernanda))
    sign_in users(:fernanda)

    get room_path(sala)

    assert_response :success
    assert_equal "waiting", sala.reload.status
  end

  # --- start ---

  test "POST /rooms/:id/start só o host pode iniciar" do
    sala = criar_sala(host: users(:fernanda))
    adicionar_jogador(sala, users(:visitante))
    sign_in users(:visitante)

    post start_room_path(sala)

    assert_redirected_to room_path(sala)
    assert_equal "Só quem criou a sala pode iniciar.", flash[:alert]
    assert sala.reload.waiting?
  end

  test "POST /rooms/:id/start exige status waiting" do
    sala = criar_sala(host: users(:fernanda), status: :in_progress)
    adicionar_jogador(sala, users(:visitante))
    sign_in users(:fernanda)

    post start_room_path(sala)

    assert_redirected_to room_path(sala)
    assert_nil flash[:alert]
    assert sala.reload.in_progress?
  end

  test "POST /rooms/:id/start exige pelo menos MIN_PLAYERS jogadores" do
    sala = criar_sala(host: users(:fernanda)) # só o host, 1 jogador
    sign_in users(:fernanda)

    post start_room_path(sala)

    assert_redirected_to room_path(sala)
    assert_equal "Precisa de pelo menos #{Room::MIN_PLAYERS} jogadores para começar.", flash[:alert]
    assert sala.reload.waiting?
  end

  # Regressão dos bugs #1 e #3: iniciar a sala transmite rooms/_round.html.erb
  # via broadcast_replace_to (fora de uma request normal). Antes das correções,
  # isso levantava Devise::MissingWarden (uso de current_user no partial) ou
  # ActionView::MissingTemplate (render "progress" resolvia para
  # application/_progress em vez de rooms/_progress). Se qualquer um desses
  # bugs voltasse, este teste falharia com uma exceção não tratada.
  test "POST /rooms/:id/start com jogadores suficientes inicia a sala sem levantar exceção ao transmitir a rodada" do
    sala = criar_sala(host: users(:fernanda))
    adicionar_jogador(sala, users(:visitante))
    sign_in users(:fernanda)

    post start_room_path(sala)

    assert_redirected_to room_path(sala)
    sala.reload
    assert sala.in_progress?
    assert_equal 1, sala.current_round_number
    assert sala.current_room_round.present?
    assert sala.current_room_round.active?
  end

  # --- advance ---

  test "POST /rooms/:id/advance não faz nada quando a rodada ainda não venceu" do
    sala = iniciar_sala_em_andamento(jogadores: 2)
    rodada_original = sala.current_room_round

    post advance_room_path(sala)

    assert_response :no_content
    assert_equal rodada_original.id, sala.reload.current_room_round_id
    assert sala.current_room_round.reload.active?
  end

  test "POST /rooms/:id/advance finaliza a rodada quando todos já responderam" do
    sala = iniciar_sala_em_andamento(jogadores: 2)
    rodada = sala.current_room_round
    rodada.room.room_players.each_with_index do |rp, i|
      GameRound.create!(user: rp.user, country: rodada.country, room_round: rodada,
        guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5 + i)
    end

    post advance_room_path(sala)

    assert_response :no_content
    assert rodada.reload.finished?
    assert rodada.ended_at.present?
  end

  test "POST /rooms/:id/advance é idempotente quando chamado duas vezes seguidas" do
    sala = iniciar_sala_em_andamento(jogadores: 2)
    rodada = sala.current_room_round
    rodada.room.room_players.each_with_index do |rp, i|
      GameRound.create!(user: rp.user, country: rodada.country, room_round: rodada,
        guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5 + i)
    end

    post advance_room_path(sala)
    assert rodada.reload.finished?
    primeiro_ended_at = rodada.ended_at

    post advance_room_path(sala)

    assert_response :no_content
    assert_equal primeiro_ended_at, rodada.reload.ended_at
  end

  test "POST /rooms/:id/advance começa a próxima rodada depois da pausa de revelação" do
    sala = iniciar_sala_em_andamento(jogadores: 2, total_rounds: 3)
    rodada = sala.current_room_round
    rodada.finalize!

    travel_to(rodada.ended_at + Room::REVEAL_PAUSE_SECONDS + 1.second) do
      post advance_room_path(sala)
    end

    sala.reload
    assert_equal 2, sala.current_round_number
    assert sala.current_room_round_id != rodada.id
    assert sala.current_room_round.active?
  end

  test "POST /rooms/:id/advance termina o jogo depois da última rodada" do
    sala = iniciar_sala_em_andamento(jogadores: 2, total_rounds: 1)
    rodada = sala.current_room_round
    rodada.finalize!

    travel_to(rodada.ended_at + Room::REVEAL_PAUSE_SECONDS + 1.second) do
      post advance_room_path(sala)
    end

    assert sala.reload.finished?
  end

  private

  def criar_sala(host:, status: :waiting, **attrs)
    sala = Room.create!(host: host, status: status, **attrs)
    sala.room_players.create!(user: host)
    sala
  end

  def adicionar_jogador(sala, user)
    sala.room_players.create!(user: user)
  end

  def adicionar_jogadores(sala, count)
    Array.new(count) do |i|
      user = User.create!(email: "extra_#{SecureRandom.hex(4)}_#{i}@example.com", password: "password123")
      adicionar_jogador(sala, user)
      user
    end
  end

  # Sala já em andamento (via POST /start real), com o host autenticado.
  def iniciar_sala_em_andamento(jogadores:, total_rounds: 5)
    sala = criar_sala(host: users(:fernanda), total_rounds: total_rounds)
    adicionar_jogadores(sala, jogadores - 1)
    sign_in users(:fernanda)

    post start_room_path(sala)
    sala.reload
  end
end
