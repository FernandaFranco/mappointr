require "test_helper"

# Cobertura do callback `before_validation :calculate_distance_and_result`
# (app/models/game_round.rb) junto com `Country#distance_from` (app/models/country.rb).
#
# A fixture `countries(:atlantis)` é um quadrado de 10°x10° cobrindo lng 0–10 e
# lat 0–10. Chutes a leste sobre o equador (lat 0.0) medem a distância até a
# aresta lng = 10, o que dá controle fino sobre a distância.
#
# Os valores de `distance_km` abaixo não são estimativas: foram medidos rodando
# o ST_Distance real do PostGIS contra essa fronteira e são o que o app grava.
class GameRoundTest < ActiveSupport::TestCase
  # Chute confortavelmente dentro da fronteira → distância 0 e "correct".
  test "chute dentro do país é correct com distância zero" do
    jogada = criar_jogada(lat: 5.0, lng: 5.0)

    assert_equal 0, jogada.distance_km
    assert_equal "correct", jogada.result
  end

  # Ponto exatamente sobre a aresta leste ainda conta como dentro.
  test "chute em cima da fronteira é correct com distância zero" do
    jogada = criar_jogada(lat: 0.0, lng: 10.0)

    assert_equal 0, jogada.distance_km
    assert_equal "correct", jogada.result
  end

  # lng 14.485 → PostGIS devolve 499.3... km, arredondado para 499: logo abaixo
  # do CLOSE_THRESHOLD_KM.
  test "chute logo abaixo do limite de 500km é close" do
    jogada = criar_jogada(lat: 0.0, lng: 14.485)

    assert_equal 499, jogada.distance_km
    assert_equal "close", jogada.result
  end

  # lng 14.492 → 500.0... km, arredondado para exatamente 500. O código usa `<=`,
  # então o próprio limite ainda é "close".
  test "chute exatamente no limite de 500km é close" do
    jogada = criar_jogada(lat: 0.0, lng: 14.492)

    assert_equal GameRound::CLOSE_THRESHOLD_KM, jogada.distance_km
    assert_equal "close", jogada.result
  end

  # lng 14.498 → 500.7... km, arredondado para 501: primeiro valor inteiro acima
  # do limite, portanto "wrong".
  test "chute logo acima do limite de 500km é wrong" do
    jogada = criar_jogada(lat: 0.0, lng: 14.498)

    assert_equal 501, jogada.distance_km
    assert_equal "wrong", jogada.result
  end

  test "chute do outro lado do mundo é wrong" do
    jogada = criar_jogada(lat: -30.0, lng: 150.0)

    assert_equal 14641, jogada.distance_km
    assert_equal "wrong", jogada.result
  end

  # lng 10.005 → PostGIS devolve 0.5565974... km (≈557m fora da fronteira).
  # `GameRound#calculate_distance_and_result` usa `.round` (não `.to_i`), então
  # essa distância vira 1km em vez de ser truncada para 0 e premiada como "correct".
  test "chute algumas centenas de metros fora da fronteira é close, não correct" do
    jogada = criar_jogada(lat: 0.0, lng: 10.005)

    assert_not_equal 0, jogada.distance_km
    assert_equal "close", jogada.result
  end

  # --- room_round_id: uniqueness (feature de salas multiplayer) ---

  # validates :room_round_id, uniqueness: { scope: :user_id }, allow_nil: true
  test "um usuário não pode ter duas jogadas na mesma room_round" do
    room_round = criar_room_round
    primeira = GameRound.create!(user: users(:fernanda), country: countries(:atlantis),
      room_round: room_round, guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5)
    assert primeira.persisted?

    segunda = GameRound.new(user: users(:fernanda), country: countries(:atlantis),
      room_round: room_round, guessed_lat: 6.0, guessed_lng: 6.0, time_seconds: 5)

    assert_not segunda.valid?
    assert_includes segunda.errors[:room_round_id], "has already been taken"
  end

  test "usuários diferentes podem ter uma jogada cada na mesma room_round" do
    room_round = criar_room_round
    GameRound.create!(user: users(:fernanda), country: countries(:atlantis),
      room_round: room_round, guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5)

    de_outro_usuario = GameRound.new(user: users(:visitante), country: countries(:atlantis),
      room_round: room_round, guessed_lat: 6.0, guessed_lng: 6.0, time_seconds: 5)

    assert de_outro_usuario.valid?
  end

  test "room_round_id nulo (jogo solo) não é afetado pela unicidade de sala" do
    GameRound.create!(user: users(:fernanda), country: countries(:atlantis),
      guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5)

    outra_jogada_solo = GameRound.new(user: users(:fernanda), country: countries(:atlantis),
      guessed_lat: 6.0, guessed_lng: 6.0, time_seconds: 5)

    assert outra_jogada_solo.valid?
  end

  # A validação Rails é só uma conveniência — o índice único parcial do banco
  # (index_game_rounds_on_user_and_room_round, WHERE room_round_id IS NOT NULL)
  # é o backstop real. Testamos isso pulando a validação para provar que o
  # próprio banco rejeita a segunda linha.
  test "o índice único parcial do banco rejeita duas jogadas do mesmo usuário na mesma room_round, mesmo pulando validação" do
    room_round = criar_room_round
    GameRound.create!(user: users(:fernanda), country: countries(:atlantis),
      room_round: room_round, guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5)

    segunda = GameRound.new(user: users(:fernanda), country: countries(:atlantis), room_round: room_round,
      guessed_lat: 6.0, guessed_lng: 6.0, distance_km: 0, result: :correct, time_seconds: 5)

    assert_raises(ActiveRecord::RecordNotUnique) do
      segunda.save(validate: false)
    end
  end

  private

  # Cria uma jogada real (dispara o callback) e recarrega do banco, para que as
  # asserções sejam sobre o que ficou persistido.
  def criar_jogada(lat:, lng:)
    GameRound.create!(
      user: users(:fernanda),
      country: countries(:atlantis),
      guessed_lat: lat,
      guessed_lng: lng,
      time_seconds: 10
    ).reload
  end

  # Cria uma room_round mínima só para exercitar a unicidade de room_round_id
  # em GameRound — não precisamos de uma sala "de verdade" (com jogadores,
  # status in_progress etc.) para esses testes.
  def criar_room_round
    room = Room.create!(host: users(:fernanda))
    RoomRound.create!(room: room, country: countries(:atlantis), round_number: 1, started_at: Time.current)
  end
end
