import { Controller } from "@hotwired/stimulus"
import { whenLeafletReady } from "leaflet_ready"
import { loadWorldBoundaries, drawWorldBoundaries } from "world_boundaries"

/**
 * ResultMapController - Mostra o mapa de resultado
 *
 * Exibe:
 * - Polígono do país destacado em verde
 * - Um ponto cinza por chute já feito nesse país por qualquer jogador (ver
 *   GameRound.guess_points) — sem identidade, sem cor por resultado, um
 *   dispersão de pontos simples, cada chute um ponto, sem agregação
 *   nenhuma. Vazio quando ninguém mais jogou.
 * - Marcador do chute do jogador, colorido pelo resultado (verde = correct,
 *   âmbar = close, vermelho = wrong) — mesma paleta usada em toda a página.
 * - Linha tracejada até o ponto mais próximo da fronteira
 */
export default class extends Controller {
  static values = {
    guessedLat: Number,
    guessedLng: Number,
    centroidLat: Number,
    centroidLng: Number,
    nearestLat: Number,
    nearestLng: Number,
    countryName: String,
    boundary: String,
    isCorrect: Boolean,
    result: String,
    guessPoints: Array
  }

  static GUESS_POINT_COLOR = "#6b7280"

  static COLORS = {
    correct: "#16a34a",
    close: "#ca8a04",
    wrong: "#dc2626"
  }

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
    const guessCoords = [this.guessedLatValue, this.guessedLngValue]
    const nearestCoords = [this.nearestLatValue, this.nearestLngValue]
    const centroidCoords = [this.centroidLatValue, this.centroidLngValue]

    // Cria o mapa
    this.map = L.map(this.element, {
      center: centroidCoords,
      zoom: 2,
      minZoom: 1,
      maxZoom: 10
    })

    // "Oceano": cor de fundo do próprio container, por baixo dos países
    this.element.style.backgroundColor = "#eff6ff"

    // Fundo com todo país do mundo. Importante desenhar ANTES do destaque do
    // país e dos pontos de chute (não só "em paralelo"): o polígono do país
    // e os pontos usam o mesmo overlayPane/renderer SVG que essa camada de
    // fundo, então quem for adicionado por último fica por cima — se essa
    // camada entrasse depois (ex: só um .then() sem esperar), ela cobriria
    // o destaque verde e os pontos assim que a rede respondesse, mesmo eles
    // já estando na tela havia um tempo. Falha aberta: se a rede cair, o
    // resto do mapa (o que realmente importa pro jogo) desenha igual.
    try {
      const boundaries = await loadWorldBoundaries()
      drawWorldBoundaries(this.map, boundaries)
    } catch (e) {
      console.error("Erro ao carregar os países:", e)
    }

    // Desenha o polígono do país
    if (this.boundaryValue) {
      try {
        const geojson = JSON.parse(this.boundaryValue)
        const countryLayer = L.geoJSON(geojson, {
          style: {
            color: "#16a34a",
            weight: 2,
            fillColor: "#22c55e",
            fillOpacity: 0.3
          }
        }).addTo(this.map)

        // Ajusta o mapa para mostrar o país e o chute
        const countryBounds = countryLayer.getBounds()
        countryBounds.extend(guessCoords)
        this.map.fitBounds(countryBounds, { padding: [30, 30] })
      } catch (e) {
        console.error("Erro ao parsear GeoJSON:", e)
      }
    }

    this.drawGuessPoints()

    // Marcador do chute, colorido pelo resultado.
    const guessColor = this.constructor.COLORS[this.resultValue] || "#dc2626"

    const guessIcon = L.divIcon({
      className: "guess-marker",
      html: `<div style="
        width: 20px;
        height: 20px;
        background-color: ${guessColor};
        border: 3px solid white;
        border-radius: 50%;
        box-shadow: 0 2px 5px rgba(0,0,0,0.3);
      "></div>`,
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    })

    L.marker(guessCoords, { icon: guessIcon })
      .addTo(this.map)
      .bindPopup("Seu chute")

    // Se não acertou, desenha a linha até o ponto mais próximo da fronteira
    if (!this.isCorrectValue) {
      // Marcador do ponto mais próximo na fronteira
      const nearestIcon = L.divIcon({
        className: "nearest-marker",
        html: `<div style="
          width: 12px;
          height: 12px;
          background-color: #16a34a;
          border: 2px solid white;
          border-radius: 50%;
          box-shadow: 0 1px 3px rgba(0,0,0,0.3);
        "></div>`,
        iconSize: [12, 12],
        iconAnchor: [6, 6]
      })

      L.marker(nearestCoords, { icon: nearestIcon })
        .addTo(this.map)
        .bindPopup("Ponto mais próximo")

      // Linha tracejada do chute até a fronteira
      L.polyline([guessCoords, nearestCoords], {
        color: "#ef4444",
        weight: 2,
        dashArray: "5, 10",
        opacity: 0.8
      }).addTo(this.map)
    }

    console.log("Mapa de resultado inicializado")
  }

  // Um ponto cinza por chute já feito no país, sem popup e sem identidade —
  // só posição. Sem agregação, sem limite: cada chute vira um ponto de verdade.
  drawGuessPoints() {
    this.guessPointsValue.forEach((ponto) => {
      L.circleMarker([ ponto.lat, ponto.lng ], {
        radius: 4,
        color: this.constructor.GUESS_POINT_COLOR,
        fillColor: this.constructor.GUESS_POINT_COLOR,
        fillOpacity: 0.5,
        weight: 1
      }).addTo(this.map)
    })
  }
}
