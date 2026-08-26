import { Controller } from "@hotwired/stimulus"
import { whenLeafletReady } from "leaflet_ready"
import { loadWorldBoundaries, drawWorldBoundaries } from "world_boundaries"

/**
 * StatsMapController - Mapa-múndi interativo da página de estatísticas
 * globais (/stats).
 *
 * Países com pelo menos uma rodada jogada aparecem destacados e clicáveis.
 * Clicar num deles carrega o turbo-frame #country-stats-panel (GET
 * /stats/:id), que por sua vez dispara o evento country-guess-points:loaded
 * (ver country_guess_points_controller.js) consumido aqui em #drawGuesses
 * pra desenhar os pontos de chute daquele país no mapa.
 */
export default class extends Controller {
  static values = { countries: Array }

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

    try {
      const boundaries = await loadWorldBoundaries()
      drawWorldBoundaries(this.map, boundaries)
    } catch (e) {
      console.error("Erro ao carregar os países:", e)
    }

    // Camada própria pra pontos de chute, redesenhada a cada país clicado —
    // ver #drawGuesses.
    this.guessLayer = L.layerGroup().addTo(this.map)

    this.drawPlayedCountries()
  }

  // Enquadra o mapa nos países já jogados em vez de deixar o zoom-múndi
  // padrão: com poucos países jogados (o caso comum), eles ficariam minúsculos
  // e difíceis de clicar espalhados num mapa-múndi inteiro.
  drawPlayedCountries() {
    let bounds = null

    this.countriesValue.forEach((country) => {
      const geojson = JSON.parse(country.boundary)

      const layer = L.geoJSON(geojson, {
        style: {
          color: "#4338ca",
          weight: 2,
          fillColor: "#818cf8",
          fillOpacity: 0.35,
          // className por país (não só um genérico "played-country"): dá pra
          // testes de sistema mirarem um país específico sem depender de
          // onde ele cai na tela — mesma técnica de world_boundaries.js.
          className: `played-country played-country-${country.id}`
        }
      }).addTo(this.map)

      layer.on("mouseover", () => layer.setStyle({ fillOpacity: 0.6 }))
      layer.on("mouseout", () => layer.setStyle({ fillOpacity: 0.35 }))
      layer.on("click", () => {
        const frame = document.getElementById("country-stats-panel")
        if (frame) frame.src = `/stats/${country.id}`
      })

      bounds = bounds ? bounds.extend(layer.getBounds()) : layer.getBounds()
    })

    if (bounds) {
      this.map.fitBounds(bounds, { padding: [ 30, 30 ] })
    }
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
