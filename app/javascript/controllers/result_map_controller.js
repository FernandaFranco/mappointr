import { Controller } from "@hotwired/stimulus"

/**
 * ResultMapController - Mostra o mapa de resultado
 *
 * Exibe:
 * - Polígono do país destacado em verde
 * - Mapa de calor com todo chute já feito nesse país por qualquer jogador
 *   (agregado em grade no servidor, ver GameRound.heatmap_points — sem
 *   identidade nenhuma, só densidade). Vazio quando ninguém mais jogou.
 * - Marcador vermelho: onde o jogador chutou
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
    points: Array
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

    // Marcador do chute (vermelho)
    const guessIcon = L.divIcon({
      className: "guess-marker",
      html: `<div style="
        width: 24px;
        height: 24px;
        background-color: #dc2626;
        border: 3px solid white;
        border-radius: 50%;
        box-shadow: 0 2px 5px rgba(0,0,0,0.3);
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 12px;
        font-weight: bold;
      ">?</div>`,
      iconSize: [24, 24],
      iconAnchor: [12, 12]
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
}
