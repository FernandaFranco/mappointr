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
 * A correção: sempre que a aba volta a ficar visível OU a janela volta a
 * ficar em foco, recarrega a página (uma visita Turbo normal em rooms#show,
 * que já sabe montar a view certa pro estado atual e pro usuário atual).
 * Não tenta adivinhar se algo mudou — sempre resincroniza.
 *
 * Por que os dois eventos, não só visibilitychange: a Page Visibility API
 * cobre trocar de aba ou minimizar a janela, mas trocar pra OUTRO
 * APLICATIVO do sistema operacional sem minimizar o Chrome (ex: Cmd+Tab no
 * Mac) muitas vezes NÃO dispara visibilitychange nenhum — document.hidden
 * continua false o tempo todo, porque a aba segue sendo "a aba ativa" da
 * janela do Chrome, mesmo com o usuário de fato olhando pra outro app. É
 * exatamente esse o caso relatado: "saí do navegador e voltei" não avançava
 * sozinho, só um F5 mostrava o estado certo — window.focus é o sinal certo
 * pra "o usuário voltou a olhar pra essa janela", cobrindo o que
 * visibilitychange sozinho deixa passar.
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
    this.handleReturn = this.handleReturn.bind(this)
    document.addEventListener("visibilitychange", this.handleReturn)
    window.addEventListener("focus", this.handleReturn)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.handleReturn)
    window.removeEventListener("focus", this.handleReturn)
  }

  handleReturn() {
    if (document.hidden) return

    Turbo.visit(window.location.href, { action: "replace" })
  }
}
