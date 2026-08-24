require "test_helper"

class PurgeGuestUsersJobTest < ActiveSupport::TestCase
  test "apaga convidados criados há mais que o limite de inatividade, com as jogadas em cascata" do
    velho = User.create_guest!
    velho.update_column(:created_at, PurgeGuestUsersJob::GUEST_INACTIVITY_THRESHOLD.ago - 1.minute)
    rodada = GameRound.create!(user: velho, country: countries(:atlantis),
      guessed_lat: 5.0, guessed_lng: 5.0, time_seconds: 5)

    PurgeGuestUsersJob.perform_now

    assert_nil User.find_by(id: velho.id)
    assert_nil GameRound.find_by(id: rodada.id)
  end

  test "não apaga convidados criados dentro do limite de inatividade" do
    recente = User.create_guest!
    recente.update_column(:created_at, PurgeGuestUsersJob::GUEST_INACTIVITY_THRESHOLD.ago + 1.minute)

    PurgeGuestUsersJob.perform_now

    assert User.exists?(id: recente.id)
  end

  test "não apaga usuários reais, mesmo com created_at muito antigo" do
    users(:novato).update_column(:created_at, PurgeGuestUsersJob::GUEST_INACTIVITY_THRESHOLD.ago - 1.year)

    PurgeGuestUsersJob.perform_now

    assert User.exists?(id: users(:novato).id)
  end
end
