require "test_helper"

# Cobertura de app/jobs/room_sweep_job.rb: o job em si não tem lógica de
# tempo nenhuma (ela mora inteira em RoomRound#due_for_finalization? e em
# Room#advance!) — o que precisa ser testado aqui é só (a) o escopo
# Room.in_progress realmente exclui salas waiting/finished do sweep, (b)
# find_each realmente itera todas as salas elegíveis, não só a primeira, e
# (c) o job reaproveita o mesmo broadcast que RoomsController#advance usa,
# sem levantar exceção fora do contexto de uma request HTTP normal (ver
# histórico de bugs #1/#3 documentado em rooms_controller_test.rb e
# room_guesses_controller_test.rb).
class RoomSweepJobTest < ActiveSupport::TestCase
  # turbo-rails só inclui esse helper automaticamente depois que ActionCable::Base
  # carrega (via ActiveSupport.on_load(:action_cable)) — sob Rails 8 esse load hook
  # nem sempre disparou a tempo do corpo desta classe ser avaliado, deixando a
  # constante indefinida. Require explícito remove a dependência dessa ordem.
  require "turbo/broadcastable/test_helper"
  include Turbo::Broadcastable::TestHelper

  test "sweep finaliza a rodada de uma sala cujo tempo esgotou" do
    room = iniciar_sala_em_andamento(jogadores: 2)
    rodada = room.current_room_round

    travel_to(rodada.started_at + room.round_duration_seconds + 1.second) do
      RoomSweepJob.perform_now
    end

    assert rodada.reload.finished?
  end

  test "sweep avança para a próxima rodada quando a pausa de reveal já passou" do
    room = iniciar_sala_em_andamento(jogadores: 2, total_rounds: 2)
    rodada = room.current_room_round
    rodada.finalize!
    rodada_original_id = rodada.id

    travel_to(rodada.ended_at + Room::REVEAL_PAUSE_SECONDS + 1.second) do
      RoomSweepJob.perform_now
    end

    room.reload
    assert room.in_progress?
    assert_equal 2, room.current_round_number
    assert_not_equal rodada_original_id, room.current_room_round_id
    assert room.current_room_round.active?
  end

  test "sweep finaliza a sala (status finished) quando a última rodada passou da pausa de reveal" do
    room = iniciar_sala_em_andamento(jogadores: 2, total_rounds: 1)
    rodada = room.current_room_round
    rodada.finalize!

    travel_to(rodada.ended_at + Room::REVEAL_PAUSE_SECONDS + 1.second) do
      RoomSweepJob.perform_now
    end

    room.reload
    assert room.finished?
    assert_equal rodada.id, room.current_room_round_id, "a última rodada finalizada continua sendo a atual, só a sala muda de status"
  end

  test "sweep não altera sala cuja rodada ainda não venceu" do
    room = iniciar_sala_em_andamento(jogadores: 2)
    rodada = room.current_room_round

    travel_to(rodada.started_at + 1.second) do
      RoomSweepJob.perform_now
    end

    assert_equal rodada.id, room.reload.current_room_round_id
    assert room.current_room_round.reload.active?
  end

  test "sweep ignora salas waiting e finished mesmo que a rodada atual pareça vencida" do
    sala_waiting = Room.create!(host: users(:fernanda), status: :waiting)

    sala_finished = iniciar_sala_em_andamento(jogadores: 2, total_rounds: 1)
    rodada_finished = sala_finished.current_room_round
    # Força o status pra finished sem passar por advance! — se o job
    # respeitasse só o status por acidente (ex: escopo errado), a rodada
    # "esquecida" em active abaixo seria finalizada mesmo assim.
    sala_finished.update_column(:status, Room.statuses[:finished])

    assert_not_includes Room.in_progress, sala_waiting
    assert_not_includes Room.in_progress, sala_finished

    travel_to(rodada_finished.started_at + sala_finished.round_duration_seconds + 1.second) do
      RoomSweepJob.perform_now
    end

    assert sala_waiting.reload.waiting?
    assert_nil sala_waiting.current_room_round_id
    assert sala_finished.reload.finished?
    assert rodada_finished.reload.active?, "a rodada da sala finished não deveria ter sido tocada pelo sweep"
  end

  test "sweep processa duas salas elegíveis na mesma varredura" do
    sala_a = iniciar_sala_em_andamento(jogadores: 2)
    sala_b = iniciar_sala_em_andamento(jogadores: 2)
    rodada_a = sala_a.current_room_round
    rodada_b = sala_b.current_room_round

    travel_to([ rodada_a.started_at, rodada_b.started_at ].max + 100.seconds) do
      RoomSweepJob.perform_now
    end

    assert rodada_a.reload.finished?
    assert rodada_b.reload.finished?
  end

  # Regressão dos bugs #1/#3 (current_user e render sem path completo
  # quebrando fora de uma request real): rodar o job contra uma sala cuja
  # rodada está vencida não pode levantar exceção, e precisa disparar o
  # mesmo broadcast que RoomsController#advance dispararia.
  test "sweep transmite o resultado da rodada sem levantar exceção" do
    room = iniciar_sala_em_andamento(jogadores: 2)
    rodada = room.current_room_round

    travel_to(rodada.started_at + room.round_duration_seconds + 1.second) do
      assert_turbo_stream_broadcasts room do
        RoomSweepJob.perform_now
      end
    end
  end

  private

  def adicionar_jogadores(sala, count)
    Array.new(count) do |i|
      user = User.create!(email: "sweep_extra_#{SecureRandom.hex(4)}_#{i}@example.com", password: "password123")
      sala.room_players.create!(user: user)
      user
    end
  end

  # difficulty: :medium força Country.random a sortear sempre
  # countries(:atlantis) (a única fixture jogável com essa dificuldade).
  # Diferente do helper homônimo em rooms_controller_test.rb, este não passa
  # por uma request HTTP (start_room_path) — o job não precisa de usuário
  # autenticado, então vamos direto pelo caminho usado em room_test.rb.
  def iniciar_sala_em_andamento(jogadores:, total_rounds: 5, difficulty: :medium)
    room = Room.create!(host: users(:fernanda), total_rounds: total_rounds, difficulty: difficulty)
    room.room_players.create!(user: users(:fernanda))
    adicionar_jogadores(room, jogadores - 1)

    room.update!(status: :in_progress)
    room.start_next_round!
    room
  end
end
