import { Controller } from "@hotwired/stimulus"
import { whenLeafletReady } from "leaflet_ready"
import { loadWorldBoundaries, drawWorldBoundaries } from "world_boundaries"

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
    // Cria o mapa centrado no mundo (view global)
    this.map = L.map(this.element, {
      center: [20, 0],      // Centro do mundo (um pouco ao norte do equador)
      zoom: 2,              // Zoom global para ver todos os continentes
      minZoom: 2,           // Não deixa dar zoom out demais
      maxZoom: 10,          // Não deixa dar zoom in demais
      worldCopyJump: true,  // Permite scroll horizontal infinito
    })

    // "Oceano": cor de fundo do próprio container, por baixo dos países
    this.element.style.backgroundColor = "#eff6ff"

    // Adiciona listener de clique no mapa
    this.map.on("click", this.handleMapClick.bind(this))

    // Marcador do chute (inicialmente null)
    this.guessMarker = null

    // Força recálculo do tamanho (fix para containers com dimensões dinâmicas)
    setTimeout(() => {
      this.map.invalidateSize()
    }, 100)

    // O placeholder "Carregando mapa..." só sai quando os países terminarem
    // de desenhar — antes disso o mapa é só um retângulo azul vazio, o que
    // pareceria quebrado. Em caso de falha (rede fora do ar), remove o
    // placeholder de qualquer jeito: clicar em qualquer lugar do oceano
    // ainda registra um chute válido, o jogo não depende dessa camada.
    loadWorldBoundaries()
      .then((boundaries) => drawWorldBoundaries(this.map, boundaries))
      .catch((e) => console.error("Erro ao carregar os países:", e))
      .finally(() => {
        if (this.hasPlaceholderTarget) this.placeholderTarget.remove()
      })

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
