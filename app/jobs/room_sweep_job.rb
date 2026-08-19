# Varre salas em andamento periodicamente (ver config/recurring.yml) e
# tenta avançá-las. Existe pra cobrir o caso de todos os jogadores terem
# saído/fechado a aba antes do fim da rodada — sem isso, nada mais avisa o
# servidor de que é hora de finalizar/avançar (o ping do cliente, via
# room_countdown_controller.js, é o caminho rápido normal; este job é só o
# fallback pra sala abandonada).
#
# Reaproveita Room#advance! (a mesma lógica que RoomsController#advance usa)
# — segura pra chamar em qualquer sala a qualquer momento, já que ela
# recalcula tudo a partir do banco e só age se realmente for a hora.
class RoomSweepJob < ApplicationJob
  queue_as :default

  def perform
    Room.in_progress.find_each(&:advance!)
  end
end
