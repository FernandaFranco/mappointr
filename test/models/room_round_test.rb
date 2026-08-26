require "test_helper"

# Cobertura de app/models/room_round.rb: all_answered?/time_elapsed?/
# due_for_finalization? nos seus limites, finalize! (pontuação e a
# regressão do bug #2 — update_all não atualiza o objeto em memória, então
# finalize! precisa dar reload em si mesmo), e unanswered_players.
#
# Os valores de distância abaixo foram medidos rodando o fluxo real
# (bin/rails runner) contra a fixture countries(:atlantis):
# - um chute em (5.0, 5.0) fica dentro da fronteira → distance_km 0, correct
# - um chute em (0.0, 14.485) fica a 499km da fronteira → close
class RoomRoundTest < ActiveSupport::TestCase
  test "all_answered? é false até que todos os jogadores tenham uma jogada" do
    round = build_active_round(players: 2)

    assert_not round.all_answered?

    responder(round, room_players(round).first)
    assert_not round.all_answered?

    responder(round, room_players(round).second)
    assert round.all_answered?
  end

  test "time_elapsed? no limiar exato de round_duration_seconds" do
    round = build_active_round(players: 2, round_duration_seconds: 45)

    travel_to(round.started_at + 44.seconds) { assert_not round.time_elapsed? }
    travel_to(round.started_at + 45.seconds) { assert round.time_elapsed? }
    travel_to(round.started_at + 46.seconds) { assert round.time_elapsed? }
  end

  test "due_for_finalization? é false enquanto a rodada está ativa, ninguém respondeu e o tempo não passou" do
    round = build_active_round(players: 2, round_duration_seconds: 45)

    travel_to(round.started_at + 10.seconds) do
      assert_not round.due_for_finalization?
    end
  end

  test "due_for_finalization? é true quando todos responderam, mesmo antes do tempo acabar" do
    round = build_active_round(players: 2, round_duration_seconds: 45)
    room_players(round).each { |rp| responder(round, rp) }

    travel_to(round.started_at + 1.second) do
      assert round.due_for_finalization?
    end
  end

  test "due_for_finalization? é true quando o tempo esgotou, mesmo sem ninguém ter respondido" do
    round = build_active_round(players: 2, round_duration_seconds: 45)

    travel_to(round.started_at + 45.seconds) do
      assert round.due_for_finalization?
    end
  end

  test "due_for_finalization? é false para uma rodada já finalizada, mesmo com o tempo esgotado" do
    round = build_active_round(players: 2, round_duration_seconds: 45)
    round.finalize!

    travel_to(round.started_at + 1.hour) do
      assert_not round.reload.due_for_finalization?
    end
  end

  test "finalize! retorna true na primeira chamada e false em chamadas subsequentes" do
    round = build_active_round(players: 2)

    assert round.finalize!
    assert_not round.finalize!, "uma segunda chamada não deveria conseguir reclamar a transição de novo"
  end

  # Bug #2: update_all não atualiza os atributos em memória. finalize! precisa
  # dar reload em si mesmo para que quem chama o método veja status/ended_at
  # atualizados no MESMO objeto, sem precisar de um reload manual à parte.
  test "finalize! atualiza status e ended_at no mesmo objeto em memória, sem reload manual" do
    round = build_active_round(players: 2)

    assert_nil round.ended_at
    assert round.active?

    round.finalize!

    assert round.finished?, "status deveria estar finished no objeto que chamou finalize!, sem round.reload"
    assert round.ended_at.present?, "ended_at deveria estar preenchido no objeto que chamou finalize!, sem round.reload"
  end

  test "finalize! não cria jogada para quem não respondeu" do
    round = build_active_round(players: 2)
    respondeu, nao_respondeu = room_players(round)
    responder(round, respondeu)

    round.finalize!

    assert_nil round.game_rounds.find_by(user_id: nao_respondeu.user_id)
    assert_equal 1, round.game_rounds.count
  end

  test "finalize! não cria jogada extra para quem já respondeu" do
    round = build_active_round(players: 2)
    round.room.room_players.each { |rp| responder(round, rp) }

    round.finalize!

    assert_equal 2, round.game_rounds.count
  end

  test "finalize! premia pontos conforme RESULT_POINTS para quem respondeu" do
    round = build_active_round(players: 3)
    acertou, quase, nao_respondeu = room_players(round)

    responder(round, acertou, lat: 5.0, lng: 5.0)     # dentro de Atlantis → correct
    responder(round, quase, lat: 0.0, lng: 14.485)     # 499km da fronteira → close
    # nao_respondeu não joga — não recebe game_round nenhuma, não pontua

    round.finalize!

    assert_equal 1000, acertou.reload.score
    assert_equal 500, quase.reload.score
    assert_equal 0, nao_respondeu.reload.score
    assert_equal 2, round.game_rounds.count
  end

  test "unanswered_players retorna jogadores sem game_round nesta rodada" do
    round = build_active_round(players: 2)
    respondeu, nao_respondeu = room_players(round)

    assert_equal [ respondeu, nao_respondeu ].sort_by(&:id), round.unanswered_players.sort_by(&:id)

    responder(round, respondeu)

    assert_equal [ nao_respondeu ], round.unanswered_players.to_a
  end

  private

  # started_at sem microssegundos: travel_to trunca para o segundo por padrão
  # (with_usec: false), então uma started_at com frações de segundo faria as
  # comparações de limite (>= started_at + duração) falharem por questão de
  # meros microssegundos, não pela lógica em si.
  def build_active_round(players:, round_duration_seconds: 45, started_at: Time.current.change(usec: 0))
    host = users(:fernanda)
    room = Room.create!(host: host, round_duration_seconds: round_duration_seconds)
    jogadores(players).each { |u| room.room_players.create!(user: u) }

    round = RoomRound.create!(room: room, country: countries(:atlantis), round_number: 1, started_at: started_at)
    room.update!(current_room_round: round, status: :in_progress, current_round_number: 1)
    round
  end

  def jogadores(count)
    disponiveis = [ users(:fernanda), users(:visitante), users(:novato) ]
    return disponiveis.first(count) if count <= disponiveis.size

    disponiveis + Array.new(count - disponiveis.size) { User.create_player! }
  end

  def room_players(round)
    round.room.room_players.order(:id).to_a
  end

  def responder(round, room_player, lat: 5.0, lng: 5.0)
    GameRound.create!(
      user: room_player.user,
      country: round.country,
      room_round: round,
      guessed_lat: lat,
      guessed_lng: lng,
      time_seconds: 5
    )
  end
end
