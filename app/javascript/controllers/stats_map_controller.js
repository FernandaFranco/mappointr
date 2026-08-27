import { Controller } from "@hotwired/stimulus"
import { whenLeafletReady } from "leaflet_ready"

/**
 * StatsMapController - Mapa-múndi interativo da página de estatísticas
 * globais (/stats).
 *
 * Todo país é clicável, jogado ou não. Clicar num deles carrega o
 * turbo-frame #country-stats-panel (GET /stats/:id), que mostra as
 * estatísticas dele (ou "ainda não foi jogado") e dispara o evento
 * country-guess-points:loaded (ver country_guess_points_controller.js),
 * consumido aqui em #drawGuesses pra desenhar os pontos de chute daquele
 * país no mapa. Só o país clicado fica destacado — os demais voltam ao
 * estilo neutro.
 */
export default class extends Controller {
  static values = { countries: Array }

  static DEFAULT_STYLE = { color: "#94a3b8", weight: 1, fillColor: "#e2e8f0", fillOpacity: 1 }
  static HOVER_STYLE = { fillColor: "#cbd5e1" }
  static SELECTED_STYLE = { color: "#4338ca", weight: 2, fillColor: "#818cf8", fillOpacity: 0.6 }

  connect() {
    this.stopWaitingForLeaflet = whenLeafletReady(() => this.initializeMap())
  }

  disconnect() {
    this.stopWaitingForLeaflet?.()

    if (this.map) {
      this.map.remove()
    }
  }

  async initializeMap() {
    this.map = L.map(this.element, {
      center: [ 20, 0 ],
      zoom: 2,
      minZoom: 1,
      maxZoom: 8
    })

    // "Oceano": cor de fundo do próprio container, por baixo dos países
    this.element.style.backgroundColor = "#eff6ff"

    // Camada própria pra pontos de chute, redesenhada a cada país clicado —
    // ver #drawGuesses.
    this.guessLayer = L.layerGroup().addTo(this.map)
    this.selectedLayer = null

    this.drawCountries()
  }

  // Enquadra o mapa em todos os países cadastrados em vez de deixar o
  // zoom-múndi padrão: com poucos países no jogo (o caso comum), eles
  // ficariam minúsculos e difíceis de clicar espalhados num mapa-múndi
  // inteiro.
  drawCountries() {
    let bounds = null

    this.countriesValue.forEach((country) => {
      const geojson = JSON.parse(country.boundary)

      const layer = L.geoJSON(geojson, {
        style: {
          ...this.constructor.DEFAULT_STYLE,
          // className por país: dá pra testes de sistema mirarem um país
          // específico sem depender de onde ele cai na tela.
          className: `country-outline country-outline-${country.id}`
        }
      }).addTo(this.map)

      layer.on("mouseover", () => {
        if (layer !== this.selectedLayer) layer.setStyle(this.constructor.HOVER_STYLE)
      })
      layer.on("mouseout", () => {
        if (layer !== this.selectedLayer) layer.setStyle(this.constructor.DEFAULT_STYLE)
      })
      layer.on("click", () => this.selectCountry(layer, country.id))

      bounds = bounds ? bounds.extend(layer.getBounds()) : layer.getBounds()
    })

    if (bounds) {
      this.map.fitBounds(bounds, { padding: [ 30, 30 ] })
    }
  }

  selectCountry(layer, countryId) {
    if (this.selectedLayer && this.selectedLayer !== layer) {
      this.selectedLayer.setStyle(this.constructor.DEFAULT_STYLE)
    }
    layer.setStyle(this.constructor.SELECTED_STYLE)
    this.selectedLayer = layer

    const frame = document.getElementById("country-stats-panel")
    if (frame) frame.src = `/stats/${countryId}`
  }

  drawGuesses(event) {
    this.guessLayer.clearLayers()

    event.detail.points.forEach((point) => {
      L.circleMarker([ point.lat, point.lng ], {
        radius: 4,
        color: "#6b7280",
        fillColor: "#6b7280",
        fillOpacity: 0.5,
        weight: 1
      }).addTo(this.guessLayer)
    })
  }
}
