import { Controller } from "@hotwired/stimulus"

/**
 * ResultMapController - Mostra o mapa de resultado
 *
 * Exibe:
 * - Polígono do país destacado em verde
 * - Mapa de calor com todo chute já feito nesse país por qualquer jogador
 *   (agregado em grade no servidor, ver GameRound.heatmap_points — sem
 *   identidade nenhuma, só densidade). Vazio quando ninguém mais jogou.
 * - Amostra de até GameRound::SAMPLE_POINTS_LIMIT chutes individuais reais
 *   (GameRound.sample_points), coloridos por resultado — correct/close/wrong
 *   — sem popup e sem identidade nenhuma, só posição + resultado.
 * - Marcador do chute do jogador, colorido e com o mesmo emoji do resultado
 *   (🎯 correct / 👏 close / 😅 wrong) — mesma paleta e mesma linguagem visual
 *   da mensagem principal da página, não mais um "?" fixo genérico.
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
    points: Array,
    samplePoints: Array
  }

  static COLORS = {
    correct: "#16a34a",
    close: "#ca8a04",
    wrong: "#dc2626"
  }

  static EMOJIS = {
    correct: "🎯",
    close: "👏",
    wrong: "😅"
  }

  connect() {
    if (typeof L === "undefined") {
      console.error("Leaflet não carregado!")
      return
    }

    this.initializeMap()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }

  initializeMap() {
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

    // Tile layer
    L.tileLayer("https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; OpenStreetMap &copy; CARTO',
      subdomains: "abcd"
    }).addTo(this.map)

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

    this.drawHeatLayer()
    this.drawSamplePoints()

    // Marcador do chute, colorido e com o emoji do resultado — já sabemos o
    // resultado nesta página, um "?" genérico não faz mais sentido aqui.
    const guessColor = this.constructor.COLORS[this.resultValue] || "#dc2626"
    const guessEmoji = this.constructor.EMOJIS[this.resultValue] || ""

    const guessIcon = L.divIcon({
      className: "guess-marker",
      html: `<div style="
        width: 28px;
        height: 28px;
        background-color: ${guessColor};
        border: 3px solid white;
        border-radius: 50%;
        box-shadow: 0 2px 5px rgba(0,0,0,0.3);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 14px;
      ">${guessEmoji}</div>`,
      iconSize: [28, 28],
      iconAnchor: [14, 14]
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

  drawHeatLayer() {
    if (typeof L.heatLayer === "undefined") {
      console.error("Leaflet.heat não carregado!")
      return
    }

    if (this.pointsValue.length === 0) return

    const maxWeight = Math.max(...this.pointsValue.map((ponto) => ponto[2]))

    L.heatLayer(this.pointsValue, {
      radius: 25,
      blur: 15,
      maxZoom: 8,
      max: maxWeight
    }).addTo(this.map)
  }

  // Bolinhas anônimas por cima do mapa de calor: sem popup, sem identidade —
  // só posição e resultado, coloridas pra dar mais informação do que a
  // densidade sozinha (onde os acertos se concentram vs. os erros).
  drawSamplePoints() {
    this.samplePointsValue.forEach((ponto) => {
      const color = this.constructor.COLORS[ponto.result] || "#6b7280"

      L.circleMarker([ ponto.lat, ponto.lng ], {
        radius: 5,
        color,
        fillColor: color,
        fillOpacity: 0.6,
        weight: 1
      }).addTo(this.map)
    })
  }
}
