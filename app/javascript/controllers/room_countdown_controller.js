import { Controller } from "@hotwired/stimulus"

/**
 * RoomCountdownController - Mostra a contagem regressiva de uma sala
 * multiplayer (tempo da rodada ou pausa antes da próxima) e avisa o
 * servidor periodicamente para avançar o estado.
 *
 * O servidor nunca confia no timing do cliente: cada ping em advanceUrl
 * só tem efeito se o servidor, ao recalcular por conta própria, concordar
 * que já é hora de avançar. Por isso é seguro (e necessário, já que não há
 * job em background) que qualquer aba conectada fique avisando —
 * a atualização visual real chega via Turbo Stream broadcast.
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
    pingIntervalMs: { type: Number, default: 2000 }
  }

  static targets = ["display"]

  connect() {
    this.deadline = Date.now() + this.secondsLeftValue * 1000
    this.updateDisplay()

    this.tickTimer = setInterval(() => this.updateDisplay(), 500)
    this.pingTimer = setInterval(() => this.ping(), this.pingIntervalMsValue)

    // Avisa uma vez de imediato — cobre o caso de a rodada já estar
    // vencida quando este elemento aparece na tela (ex: reconexão tardia).
    this.ping()
  }

  disconnect() {
    clearInterval(this.tickTimer)
    clearInterval(this.pingTimer)
  }

  updateDisplay() {
    if (!this.hasDisplayTarget) return

    const remaining = Math.max(0, Math.round((this.deadline - Date.now()) / 1000))
    this.displayTarget.textContent = remaining
  }

  ping() {
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
