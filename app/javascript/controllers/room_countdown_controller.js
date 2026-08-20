import { Controller } from "@hotwired/stimulus"

/**
 * RoomCountdownController - Mostra a contagem regressiva de uma sala
 * multiplayer (tempo da rodada ou pausa antes da próxima) e avisa o
 * servidor periodicamente para avançar o estado.
 *
 * O servidor nunca confia no timing do cliente: cada ping em advanceUrl
 * só tem efeito se o servidor, ao recalcular por conta própria, concordar
 * que já é hora de avançar. Por isso é seguro que qualquer aba conectada
 * fique avisando — a atualização visual real chega via Turbo Stream
 * broadcast. Este ping continua sendo o caminho rápido normal (reação
 * quase instantânea enquanto alguém está com a aba aberta); o RoomSweepJob
 * em background (config/recurring.yml) é só o fallback pra quando todo
 * mundo sai da sala antes do fim da rodada — os dois chamam a mesma
 * Room#advance!, então rodar junto é seguro (idempotente).
 *
 * Duas salvaguardas contra pingar pra sempre numa aba abandonada — o fetch
 * em si sempre "funciona" (é um POST HTTP comum, não depende do WebSocket
 * do ActionCable), então não dá pra detectar aba morta só pelo sucesso do
 * ping:
 * - Pausa o ping enquanto a aba está em segundo plano (Page Visibility API)
 *   e retoma (com um ping imediato) quando ela volta a ficar visível —
 *   cobre o caso comum de "saiu da aba".
 * - Um teto absoluto de tempo desde que o elemento apareceu na tela: depois
 *   dele, para de pingar de vez, mesmo com a aba visível. Nenhuma rodada
 *   de verdade precisa de mais que isso, e o RoomSweepJob cobre o resto.
 *
 * Uso no HTML:
 *   <div data-controller="room-countdown"
 *        data-room-countdown-seconds-left-value="30"
 *        data-room-countdown-advance-url-value="/rooms/1/advance">
 *     <span data-room-countdown-target="display"></span>
 *   </div>
 */
export default class extends Controller {
  static values = {
    secondsLeft: Number,
    advanceUrl: String,
    pingIntervalMs: { type: Number, default: 2000 },
    maxPingMinutes: { type: Number, default: 30 }
  }

  static targets = ["display"]

  connect() {
    this.deadline = Date.now() + this.secondsLeftValue * 1000
    this.pingingSince = Date.now()
    this.updateDisplay()

    this.tickTimer = setInterval(() => this.updateDisplay(), 500)
    this.startPinging()

    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)

    // Avisa uma vez de imediato — cobre o caso de a rodada já estar
    // vencida quando este elemento aparece na tela (ex: reconexão tardia).
    this.ping()
  }

  disconnect() {
    clearInterval(this.tickTimer)
    this.stopPinging()
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.stopPinging()
    } else {
      this.startPinging()
      this.ping()
    }
  }

  startPinging() {
    if (this.pingTimer) return
    this.pingTimer = setInterval(() => this.ping(), this.pingIntervalMsValue)
  }

  stopPinging() {
    clearInterval(this.pingTimer)
    this.pingTimer = null
  }

  updateDisplay() {
    if (!this.hasDisplayTarget) return

    const remaining = Math.max(0, Math.round((this.deadline - Date.now()) / 1000))
    this.displayTarget.textContent = remaining
  }

  ping() {
    const elapsedMinutes = (Date.now() - this.pingingSince) / 60000
    if (elapsedMinutes >= this.maxPingMinutesValue) {
      this.stopPinging()
      return
    }

    const csrfToken = document.querySelector("meta[name='csrf-token']").content

    fetch(this.advanceUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/plain"
      }
    }).catch(() => {
      // Falha de rede momentânea não é crítica — outra aba conectada
      // (ou o próximo ping deste mesmo timer) cobre o avanço da sala.
    })
  }
}
