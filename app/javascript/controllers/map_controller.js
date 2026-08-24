import { Controller } from "@hotwired/stimulus"
import { whenLeafletReady } from "leaflet_ready"

/**
 * MapController - Controla o mapa interativo do jogo
 *
 * Uso no HTML:
 *   <div data-controller="map"
 *        data-map-country-id-value="123">
 *   </div>
 *
 * Em salas multiplayer, passe data-map-submit-url-value apontando para o
 * endpoint de chute da sala (por padrão envia para o jogo solo, /play).
 */
export default class extends Controller {
  static values = {
    countryId: Number,
    submitUrl: { type: String, default: "/play" }
  }

  static targets = ["placeholder"]

  connect() {
    console.log("MapController conectado")

    this.stopWaitingForLeaflet = whenLeafletReady(() => this.initializeMap())
  }

  disconnect() {
    // Chamado quando o elemento é removido do DOM
    this.stopWaitingForLeaflet?.()

    if (this.map) {
      this.map.remove()
    }
  }

  initializeMap() {
    // Remove o placeholder se existir
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.remove()
    }

    // Cria o mapa centrado no mundo (view global)
    this.map = L.map(this.element, {
      center: [20, 0],      // Centro do mundo (um pouco ao norte do equador)
      zoom: 2,              // Zoom global para ver todos os continentes
      minZoom: 2,           // Não deixa dar zoom out demais
      maxZoom: 10,          // Não deixa dar zoom in demais
      worldCopyJump: true,  // Permite scroll horizontal infinito
    })

    // Adiciona o tile layer (mapa base)
    // Usando CartoDB Positron - mapa clean sem muitos detalhes
    // IMPORTANTE: sem fronteiras visíveis!
    L.tileLayer("https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
      subdomains: "abcd",
      maxZoom: 20
    }).addTo(this.map)

    // Adiciona listener de clique no mapa
    this.map.on("click", this.handleMapClick.bind(this))

    // Marcador do chute (inicialmente null)
    this.guessMarker = null

    // Força recálculo do tamanho (fix para containers com dimensões dinâmicas)
    setTimeout(() => {
      this.map.invalidateSize()
    }, 100)

    console.log("Mapa inicializado!")
  }

  handleMapClick(event) {
    const { lat, lng } = event.latlng

    console.log(`Clique em: ${lat.toFixed(4)}, ${lng.toFixed(4)}`)

    // Remove marcador anterior se existir
    if (this.guessMarker) {
      this.map.removeLayer(this.guessMarker)
    }

    // Cria ícone customizado para o chute (vermelho)
    const guessIcon = L.divIcon({
      className: "guess-marker",
      html: `<div style="
        width: 20px;
        height: 20px;
        background-color: #dc2626;
        border: 3px solid white;
        border-radius: 50%;
        box-shadow: 0 2px 5px rgba(0,0,0,0.3);
      "></div>`,
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    })

    // Adiciona marcador no local clicado
    this.guessMarker = L.marker([lat, lng], { icon: guessIcon }).addTo(this.map)

    // Envia o formulário com as coordenadas
    this.submitGuess(lat, lng)
  }

  submitGuess(lat, lng) {
    // Cria um formulário invisível e submete
    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.submitUrlValue

    // Token CSRF (obrigatório no Rails)
    const csrfToken = document.querySelector("meta[name='csrf-token']").content
    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)

    // Latitude
    const latInput = document.createElement("input")
    latInput.type = "hidden"
    latInput.name = "lat"
    latInput.value = lat
    form.appendChild(latInput)

    // Longitude
    const lngInput = document.createElement("input")
    lngInput.type = "hidden"
    lngInput.name = "lng"
    lngInput.value = lng
    form.appendChild(lngInput)

    // Adiciona ao DOM e submete
    document.body.appendChild(form)
    form.submit()
  }
}
