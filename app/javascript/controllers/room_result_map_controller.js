import { Controller } from "@hotwired/stimulus"
import { whenLeafletReady } from "leaflet_ready"

/**
 * RoomResultMapController - Mostra o mapa de resultado de uma rodada de
 * sala, com o chute de CADA jogador que respondeu (não só o do usuário
 * logado, como no mapa de resultado do jogo solo).
 *
 * Exibe:
 * - Polígono do país destacado em verde
 * - Um marcador por jogador que respondeu, colorido pelo resultado
 *   (verde = correct, âmbar = close, vermelho = wrong)
 * - Popup por marcador com e-mail do jogador e distância
 *
 * Uso no HTML:
 *   <div data-controller="room-result-map"
 *        data-room-result-map-guesses-value='[{"lat":1,"lng":2,"result":"correct","email":"a@b.com","distance_km":0}]'>
 *   </div>
 */
export default class extends Controller {
  static values = {
    centroidLat: Number,
    centroidLng: Number,
    countryName: String,
    boundary: String,
    guesses: Array
  }

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
    bounds = this.drawGuesses(bounds)

    if (bounds) {
      this.map.fitBounds(bounds, { padding: [ 30, 30 ] })
    } else {
      this.map.setView(centroidCoords, 3)
    }
  }

  drawCountryBoundary() {
    if (!this.boundaryValue) return null

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

      return countryLayer.getBounds()
    } catch (e) {
      console.error("Erro ao parsear GeoJSON:", e)
      return null
    }
  }

  drawGuesses(bounds) {
    this.guessesValue.forEach((guess) => {
      const coords = [ guess.lat, guess.lng ]
      const color = this.constructor.COLORS[guess.result] || "#6b7280"

      const icon = L.divIcon({
        className: "guess-marker",
        html: `<div style="
          width: 20px;
          height: 20px;
          background-color: ${color};
          border: 3px solid white;
          border-radius: 50%;
          box-shadow: 0 2px 5px rgba(0,0,0,0.3);
        "></div>`,
        iconSize: [ 20, 20 ],
        iconAnchor: [ 10, 10 ]
      })

      // Constrói o conteúdo do popup via textContent (não template string
      // interpolada em innerHTML): guess.email vem do usuário (cadastro),
      // e o regex de e-mail do Devise é permissivo o bastante pra não
      // barrar marcação HTML — então nunca interpolamos direto em HTML.
      const popupContent = document.createElement("div")
      const emailLine = document.createElement("div")
      emailLine.textContent = guess.email
      const distanceLine = document.createElement("div")
      distanceLine.textContent = `${guess.distance_km} km`
      popupContent.appendChild(emailLine)
      popupContent.appendChild(distanceLine)

      L.marker(coords, { icon }).addTo(this.map).bindPopup(popupContent)

      bounds = bounds ? bounds.extend(coords) : L.latLngBounds([ coords, coords ])
    })

    return bounds
  }
}
