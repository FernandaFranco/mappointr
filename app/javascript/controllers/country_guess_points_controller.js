import { Controller } from "@hotwired/stimulus"

/**
 * CountryGuessPointsController - Vive dentro do turbo-frame
 * #country-stats-panel (ver stats/country.html.erb). Não desenha nada
 * sozinho: só "traduz" os pontos de chute que o servidor mandou junto com
 * as estatísticas do país num evento DOM (country-guess-points:loaded),
 * pra que stats_map_controller.js — que vive no mapa, fora deste frame —
 * consiga redesenhá-los sem precisar inspecionar o DOM do frame.
 *
 * connect() dispara de novo a cada país clicado, já que o turbo-frame troca
 * de conteúdo (e portanto reconecta este controller) a cada navegação.
 */
export default class extends Controller {
  static values = { points: Array }

  connect() {
    this.dispatch("loaded", { detail: { points: this.pointsValue } })
  }
}
