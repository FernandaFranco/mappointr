// Busca o contorno de todo país (public/world_boundaries.geojson, gerado por
// `bin/rails countries:export_boundaries` a partir dos mesmos dados que o
// jogo já usa) e desenha como camada de fundo do mapa — no lugar de um tile
// server externo. Isso é o que faz o mapa não depender de nenhum serviço de
// terceiro pra existir: sem chave de API, sem risco de quebrar se um
// provedor mudar os termos (foi exatamente isso que aconteceu com o CARTO).
//
// Sem properties nas features (ver countries:export_boundaries) — a camada
// de fundo é só silhueta, a mesma cor pra todo país, sem nome nenhum.
let cachedBoundaries = null

export async function loadWorldBoundaries() {
  if (cachedBoundaries) return cachedBoundaries

  const response = await fetch("/world_boundaries.geojson")
  cachedBoundaries = await response.json()
  return cachedBoundaries
}

export function drawWorldBoundaries(map, boundaries) {
  return L.geoJSON(boundaries, {
    style: {
      color: "#cbd5e1",
      weight: 1,
      fillColor: "#e2e8f0",
      fillOpacity: 1,
      interactive: false,
      // interactive: false tira a classe leaflet-interactive (é assim que o
      // Leaflet marca paths que respondem a clique) — className próprio é o
      // jeito de continuar identificando essa camada nos testes.
      className: "world-boundary"
    }
  }).addTo(map)
}
