import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

/**
 * RoomSyncController - Garante que, ao voltar pra aba, a página de uma sala
 * mostra o estado ATUAL de verdade, não uma tela congelada.
 *
 * O problema: Turbo Stream via ActionCable é "dispara e esquece" — se a aba
 * perder a conexão (segundo plano por tempo suficiente, rede instável,
 * notebook suspenso) enquanto a sala avança (próxima rodada, fim de jogo
 * etc.), ela nunca fica sabendo: não existe reenvio de broadcasts perdidos,
 * só os que chegam depois da reconexão. Sem isso, a aba fica presa numa
 * tela antiga pra sempre — mesmo com o RoomSweepJob avançando a sala
 * corretamente no servidor (ver app/jobs/room_sweep_job.rb) — porque
 * nenhum broadcast futuro vai "corrigir" uma transição que ela já perdeu.
 *
 * A correção: sempre que a aba volta a ficar visível, recarrega a página
 * (uma visita Turbo normal em rooms#show, que já sabe montar a view certa
 * pro estado atual e pro usuário atual). Não tenta adivinhar se algo mudou
 * — sempre resincroniza.
 *
 * Fica no elemento raiz de rooms/show.html.erb, FORA de #room_body, pra
 * nunca ser desconectado pelas trocas de conteúdo que os broadcasts fazem
 * lá dentro — precisa continuar ouvindo o tempo todo que a página existir,
 * não só enquanto uma rodada específica está na tela (a sala de espera e o
 * placar final também não têm room-countdown, mas o mesmo problema de
 * "perdeu a transição" pode acontecer lá).
 *
 * Uso no HTML:
 *   <div data-controller="room-sync">...</div>
 */
export default class extends Controller {
  connect() {
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
  }

  handleVisibilityChange() {
    if (document.hidden) return

    Turbo.visit(window.location.href, { action: "replace" })
  }
}
