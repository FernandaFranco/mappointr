# Apaga contas de visitante inativas (ver User.create_guest!, config/recurring.yml).
# Sem isso, cada clique em "Jogar sem cadastro" que não vira uma conta de
# verdade (via GuestClaimsController) deixaria uma linha de User pra sempre.
#
# GUEST_INACTIVITY_THRESHOLD é sobre created_at, não last_activity_at — ao
# contrário de Room, User não tem um campo de "última atividade" tocado a
# cada request, e não vale a pena adicionar um só pra isso. 24h é uma folga
# generosa pra sobreviver a uma sessão de jogo de verdade (fechar a aba e
# voltar no mesmo dia), mas curta o bastante pra não acumular contas órfãs
# por muito tempo.
#
# dependent: :destroy em User (game_rounds, room_players) cuida da cascata:
# apagar o visitante já leva o histórico de jogo dele junto.
class PurgeGuestUsersJob < ApplicationJob
  queue_as :default

  GUEST_INACTIVITY_THRESHOLD = 24.hours

  def perform
    User.guest.where(created_at: ...GUEST_INACTIVITY_THRESHOLD.ago).find_each(&:destroy)
  end
end
