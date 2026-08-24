// Espera o Leaflet (carregado via <script src> externo no layout) terminar
// de carregar antes de rodar o callback.
//
// Necessário porque um controller Stimulus pode conectar no elemento do DOM
// ANTES do <script> do Leaflet terminar de baixar — isso é raro numa
// navegação com reload completo (o script já carregou antes do resto da
// página renderizar), mas comum numa transição via Turbo sem reload (ex:
// redirect depois de login) onde essa é a PRIMEIRA vez que a aba carrega o
// Leaflet: o Turbo injeta o <script> dinamicamente no <head>, e o
// controller pode conectar antes do fetch externo terminar. Sem retry, o
// controller desistia na hora (`typeof L === "undefined"`) e nunca
// tentava de novo — o mapa ficava preso em "Carregando mapa..." pra
// sempre, mesmo com o Leaflet disponível um instante depois.
const MAX_ATTEMPTS = 50
const RETRY_DELAY_MS = 100

// Retorna uma função "stop" — chame no disconnect() do controller pra
// cancelar um retry ainda pendente (ex: usuário navegou pra longe antes do
// Leaflet terminar de carregar). Sem isso, o callback podia rodar depois do
// elemento já ter saído do DOM.
export function whenLeafletReady(callback) {
  let attempts = 0
  let stopped = false
  let timeoutId = null

  function check() {
    if (stopped) return

    if (typeof L !== "undefined") {
      callback()
      return
    }

    attempts += 1
    if (attempts >= MAX_ATTEMPTS) {
      console.error("Leaflet não carregou a tempo!")
      return
    }

    timeoutId = setTimeout(check, RETRY_DELAY_MS)
  }

  check()

  return function stop() {
    stopped = true
    if (timeoutId) clearTimeout(timeoutId)
  }
}
