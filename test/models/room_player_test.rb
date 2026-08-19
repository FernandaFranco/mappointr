require "test_helper"

class RoomPlayerTest < ActiveSupport::TestCase
  test "mesmo usuário não pode entrar duas vezes na mesma sala" do
    room = Room.create!(host: users(:fernanda))
    room.room_players.create!(user: users(:fernanda))

    duplicado = room.room_players.build(user: users(:fernanda))

    assert_not duplicado.valid?
    assert_includes duplicado.errors[:user_id], "has already been taken"
  end

  test "o mesmo usuário pode entrar em salas diferentes" do
    sala_a = Room.create!(host: users(:fernanda))
    sala_b = Room.create!(host: users(:visitante))
    sala_a.room_players.create!(user: users(:fernanda))

    em_outra_sala = sala_b.room_players.build(user: users(:fernanda))

    assert em_outra_sala.valid?
  end

  test "joined_at é preenchido automaticamente ao criar" do
    room = Room.create!(host: users(:fernanda))
    agora = Time.zone.local(2026, 1, 1, 12, 0, 0)

    room_player = travel_to(agora) { room.room_players.create!(user: users(:fernanda)) }

    assert_equal agora, room_player.joined_at
  end

  test "joined_at informado explicitamente não é sobrescrito" do
    room = Room.create!(host: users(:fernanda))
    passado = 3.days.ago

    room_player = room.room_players.create!(user: users(:fernanda), joined_at: passado)

    assert_in_delta passado.to_i, room_player.joined_at.to_i, 1
  end
end
