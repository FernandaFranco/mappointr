require "test_helper"
require "minitest/mock"

class RoomTest < ActiveSupport::TestCase
  test "código gerado tem 6 caracteres, todos do alfabeto sem 0/O/1/I/L" do
    room = Room.create!(host: users(:fernanda))

    assert_equal Room::CODE_LENGTH, room.code.length
    assert room.code.chars.all? { |c| Room::CODE_ALPHABET.include?(c) }
    assert_empty room.code.chars & %w[0 O 1 I L]
  end

  # Força uma colisão: o primeiro código sorteado é idêntico ao de uma sala
  # já existente, então o loop de app/models/room.rb#generate_code precisa
  # descartá-lo e sortear de novo antes de salvar.
  test "sorteia um novo código quando o primeiro sorteado já está em uso" do
    existente = Room.create!(host: users(:fernanda))
    sequence = (existente.code.chars + "ZZZZZZ".chars)

    novo = Room::CODE_ALPHABET.stub :sample, -> { sequence.shift } do
      Room.create!(host: users(:fernanda))
    end

    assert_equal "ZZZZZZ", novo.code
    assert_not_equal existente.code, novo.code
  end

  test "status inicial de uma sala nova é waiting" do
    room = Room.create!(host: users(:fernanda))

    assert room.waiting?
  end

  test "full? é false abaixo de MAX_PLAYERS e true a partir dele" do
    room = Room.create!(host: users(:fernanda))
    jogadores = [ users(:fernanda), users(:visitante), users(:novato) ] + create_users(5)

    jogadores.first(Room::MAX_PLAYERS - 1).each { |u| room.room_players.create!(user: u) }
    assert_not room.full?, "sala com #{Room::MAX_PLAYERS - 1} jogadores não deveria estar cheia"

    room.room_players.create!(user: jogadores[Room::MAX_PLAYERS - 1])
    assert room.reload.full?, "sala com #{Room::MAX_PLAYERS} jogadores deveria estar cheia"
  end

  test "enough_players_to_start? no limiar de MIN_PLAYERS" do
    room = Room.create!(host: users(:fernanda))
    room.room_players.create!(user: users(:fernanda))

    assert_not room.enough_players_to_start?, "1 jogador não é suficiente (MIN_PLAYERS = #{Room::MIN_PLAYERS})"

    room.room_players.create!(user: users(:visitante))

    assert room.reload.enough_players_to_start?, "#{Room::MIN_PLAYERS} jogadores já deveriam ser suficientes"
  end

  test "stale? é true quando last_activity_at passou de STALE_AFTER" do
    room = Room.create!(host: users(:fernanda))

    assert_not room.stale?, "sala recém-criada não deveria estar stale"

    travel Room::STALE_AFTER + 1.second do
      assert room.stale?
    end
  end

  test "stale? é false enquanto a sala ainda está dentro de STALE_AFTER" do
    room = Room.create!(host: users(:fernanda))

    travel Room::STALE_AFTER - 1.second do
      assert_not room.stale?
    end
  end

  # Independentemente de quão velha esteja last_activity_at, uma sala já
  # finalizada nunca deve ser considerada abandonada.
  test "uma sala finished nunca é stale, mesmo com atividade muito antiga" do
    room = Room.create!(host: users(:fernanda), status: :finished)

    travel Room::STALE_AFTER * 10 do
      assert_not room.stale?
    end
  end

  test "touch_activity! atualiza last_activity_at para agora" do
    room = Room.create!(host: users(:fernanda))
    momento_futuro = 10.minutes.from_now

    travel_to momento_futuro do
      room.touch_activity!
    end

    assert_in_delta momento_futuro.to_i, room.reload.last_activity_at.to_i, 1
  end

  private

  def create_users(count)
    Array.new(count) { |i| User.create!(email: "jogador_extra_#{i}_#{SecureRandom.hex(4)}@example.com", password: "password123") }
  end
end
