import { Controller } from "@hotwired/stimulus"

/**
 * CountryHeatmapController - Mostra onde todo mundo já chutou nesse país,
 * ao longo de toda a história do jogo (não só a rodada atual).
 *
 * Os pontos já vêm agregados em grade do servidor (GameRound.heatmap_points)
 * — cada [lat, lng, peso] é uma célula, não um chute individual — então não
 * há identidade de jogador nenhuma aqui, só densidade agregada. O próprio
 * chute do jogador atual ganha um marcador à parte, por cima do mapa de calor,
 * pra ele conseguir se localizar em relação ao resto.
 *
 * Uso no HTML:
 *   <div data-controller="country-heatmap"
 *        data-country-heatmap-points-value='[[5.0,5.0,3],[8.0,8.0,1]]'>
 *   </div>
 */
export default class extends Controller {
  static values = {
    centroidLat: Number,
    centroidLng: Number,
    boundary: String,
    points: Array,
    guessedLat: Number,
    guessedLng: Number
  }

  connect() {
    if (typeof L === "undefined" || typeof L.heatLayer === "undefined") {
      console.error("Leaflet ou Leaflet.heat não carregado!")
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
    const centroidCoords = [ this.centroidLatValue, this.centroidLngValue ]

    this.map = L.map(this.element, {
      center: centroidCoords,
      zoom: 2,
      minZoom: 1,
      maxZoom: 10
    })

    L.tileLayer("https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; OpenStreetMap &copy; CARTO',
      subdomains: "abcd"
    }).addTo(this.map)

    let bounds = this.drawCountryBoundary()
    this.drawHeatLayer()
    bounds = this.drawOwnGuess(bounds)

    if (bounds) {
      this.map.fitBounds(bounds, { padding: [ 30, 30 ] })
    } else {
      this.map.setView(centroidCoords, 3)
    }
  }

  // Contorno em azul (em vez do verde do mapa de resultado), pra ficar claro
  // à primeira vista que esse é um mapa diferente — agregado, não pessoal.
  drawCountryBoundary() {
    if (!this.boundaryValue) return null

    try {
      const geojson = JSON.parse(this.boundaryValue)
      const countryLayer = L.geoJSON(geojson, {
        style: {
          color: "#2563eb",
          weight: 2,
          fillColor: "#3b82f6",
          fillOpacity: 0.15
        }
      }).addTo(this.map)

      return countryLayer.getBounds()
    } catch (e) {
      console.error("Erro ao parsear GeoJSON:", e)
      return null
    }
  }

  drawHeatLayer() {
    if (this.pointsValue.length === 0) return

    const maxWeight = Math.max(...this.pointsValue.map((ponto) => ponto[2]))

    L.heatLayer(this.pointsValue, {
      radius: 25,
      blur: 15,
      maxZoom: 8,
      max: maxWeight
    }).addTo(this.map)
  }

  drawOwnGuess(bounds) {
    const coords = [ this.guessedLatValue, this.guessedLngValue ]

    const icon = L.divIcon({
      className: "own-guess-marker",
      html: `<div style="
        width: 16px;
        height: 16px;
        background-color: #dc2626;
        border: 3px solid white;
        border-radius: 50%;
        box-shadow: 0 2px 5px rgba(0,0,0,0.3);
      "></div>`,
      iconSize: [ 16, 16 ],
      iconAnchor: [ 8, 8 ]
    })

    L.marker(coords, { icon }).addTo(this.map).bindPopup("Seu chute")

    return bounds ? bounds.extend(coords) : L.latLngBounds([ coords, coords ])
  }
}
