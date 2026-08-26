require "application_system_test_case"
require "timeout"

# Fluxo multiplayer completo com duas sessões de navegador reais e
# simultâneas (Capybara::Session#using_session), provando o que os testes
# de model/controller não conseguem: que a atualização em tempo real via
# Turbo Stream realmente chega no navegador da OUTRA sessão sem reload de
# página, e que os broadcasts (bugs #1/#2/#3 corrigidos em rooms/_round.html.erb,
# RoomRound#finalize! e o render "rooms/progress") não quebram em um
# round-trip real de navegador — não só em uma request de teste simulada.
#
# Deliberadamente não afirma um resultado específico (correct/close/wrong)
# do clique no mapa: prever a coordenada exata que um clique real do
# Capybara/Selenium produz no Leaflet (projeção, zoom, tamanho de tela)
# seria frágil. O que importa aqui é que o chute é registrado e o fluxo
# multiplayer em tempo real funciona ponta a ponta — a correção do
# resultado já está coberta por RoomRoundTest/RoomGuessesControllerTest.
class RoomsTest < ApplicationSystemTestCase
  # room_countdown_controller.js (ping a cada 2s) e room_sync_controller.js
  # (ouvinte de visibilitychange) continuam ativos na página quando o
  # método de teste termina, já que nenhum destes testes navega pra longe
  # da sala antes de acabar. Isso expõe uma corrida documentada no próprio
  # Capybara (Selenium::Driver#reset_browser_state — "asynchronous JS code
  # in the application under test can navigate the browser away... if the
  # timing is just right"): um fetch autenticado ainda em voo pode receber
  # um Set-Cookie de volta DEPOIS que Capybara.reset_sessions! já limpou os
  # cookies, "ressuscitando" uma sessão logada bem na hora que o próximo
  # teste reaproveita a mesma janela/cookie jar — daí o
  # "You are already signed in." intermitente no sign_in_via_ui de um
  # teste completamente diferente. Navegar pra about:blank aqui (ANTES do
  # teardown de reset_sessions! da classe-pai, que roda depois já que
  # teardowns de subclasse rodam primeiro) derruba os controllers Stimulus
  # da página antiga — e o fetch deles junto — fechando essa janela de corrida.
  teardown do
    [ :default, :host, :guest ].each do |session_name|
      Capybara.using_session(session_name) { visit "about:blank" }
    rescue StandardError
      nil
    end
  end

  test "dois jogadores criam sala, entram, jogam uma rodada e veem o resultado em tempo real" do
    room_code = nil

    using_session(:host) do
      sign_in_via_ui(users(:fernanda))
      visit new_room_path

      fill_in "Número de rodadas", with: 1
      click_on "Criar sala"

      assert_selector "h1", text: "Sala"
      room_code = find("p.font-mono.text-red-600").text
      assert_match(/\A[A-Z0-9]{6}\z/, room_code)
      assert_text "1 jogador(es) na sala"
    end

    using_session(:guest) do
      sign_in_via_ui(users(:visitante))
      visit new_room_path

      fill_in "Ex: VT4SHF", with: room_code
      click_on "Entrar"

      assert_selector "h1", text: "Sala"
      assert_text "2 jogador(es) na sala"
    end

    # A lista de jogadores do host deve atualizar sozinha via broadcast —
    # sem recarregar a página nem navegar de novo nesta sessão.
    using_session(:host) do
      assert_text "visitante@example.com"
      click_on "Iniciar jogo"
      assert_text "Rodada 1 de 1"
    end

    # A guest nunca navegou de novo: a troca da sala de espera pra rodada
    # só pode ter chegado pelo broadcast_replace_to de #room_body. Espera o
    # placeholder sumir antes de clicar (dá tempo do Leaflet pelo menos
    # existir), mas quem realmente evita o "Node with given id does not
    # belong to the document" é click_map_and_expect — ver comentário na
    # classe-pai: o Leaflet segue mexendo no DOM (tiles chegando aos poucos)
    # mesmo depois do placeholder sumir, e isso reproduz até fora de
    # contexto de broadcast, então esperar mais não bastava sozinho.
    using_session(:guest) do
      assert_text "Rodada 1 de 1"
      assert_no_text "Carregando mapa..."
      click_map_and_expect(/Chute registrado|Resultado da rodada/)
    end

    using_session(:host) do
      assert_no_text "Carregando mapa..."
      retry_on_stale_node do
        find("#map-container").click unless page.has_text?("Resultado da rodada 1")
        assert_text "Resultado da rodada 1"
        # Prova que o novo Stimulus controller (room-result-map) realmente
        # inicializa num navegador real, sem erro de JS — os testes de
        # model/controller não conseguem verificar isso.
        assert_selector "[data-controller='room-result-map']"
      end
    end

    # A guest não recarregou — vê o resultado só porque o último chute
    # (do host) disparou finalize! + broadcast_results.
    using_session(:guest) do
      assert_text "Resultado da rodada 1"
      assert_selector "[data-controller='room-result-map']"
    end

    # Só 1 rodada: depois da pausa de revelação, a sala deve avançar
    # sozinha (via o ping periódico do room-countdown controller) direto
    # pro placar final, sem qualquer ação humana.
    using_session(:host) do
      using_wait_time(Room::REVEAL_PAUSE_SECONDS + 5) do
        assert_text "Fim de jogo!"
      end
    end
  end

  # Regressão do bug "ping infinito de aba abandonada": se o WebSocket do
  # ActionCable morre (aba em segundo plano, laptop dormiu, rede caiu) mas a
  # aba continua aberta, o Turbo Stream nunca troca o elemento do countdown
  # e o setInterval de ping ficava rodando pra sempre. room_countdown_controller.js
  # agora escuta visibilitychange e pausa/retoma o ping conforme a aba fica
  # oculta/visível. Como o teste não controla de verdade a visibilidade da
  # aba do Chrome headless, simulamos via Page Visibility API (document.hidden
  # e document.visibilityState são normalmente somente-leitura — sobrescrever
  # com Object.defineProperty e disparar o evento sintético é a mesma técnica
  # usada pra verificar manualmente esse fix antes de escrever o teste).
  #
  # A prova de que um ping chegou (ou não) é Room#last_activity_at, que
  # RoomsController#advance sempre toca via touch_activity!, mesmo quando
  # Room#advance! não faz nada (rodada ainda não venceu) — não dá pra
  # observar o ping diretamente, mas o timestamp de atividade é um proxy
  # fiel: só muda quando uma request POST /rooms/:id/advance chega.
  test "aba em segundo plano pausa o ping do countdown e retoma com ping imediato ao voltar a ficar visível" do
    sala = criar_sala_em_andamento_com_rodada_ativa

    sign_in_via_ui(sala.host)
    visit room_path(sala)

    assert_selector "[data-controller='room-countdown']"

    # O controller pinga uma vez imediatamente em connect() — espera esse
    # ping assentar antes de medir a pausa, senão ele poderia ser confundido
    # com um ping "durante" a janela oculta.
    atividade_apos_connect = esperar_last_activity_mudar(sala, desde: sala.last_activity_at)

    forcar_visibilidade_da_aba(hidden: true)

    # pingIntervalMs é 2000ms — 3s de sono cobre folgadamente uma tentativa
    # de ping que o bug antigo teria disparado nesta janela.
    sleep 3

    assert_equal atividade_apos_connect, sala.reload.last_activity_at,
      "nenhum ping deveria chegar em /advance enquanto document.hidden é true"

    forcar_visibilidade_da_aba(hidden: false)

    atividade_ao_voltar = esperar_last_activity_mudar(sala, desde: atividade_apos_connect)
    assert_operator atividade_ao_voltar, :>, atividade_apos_connect,
      "voltar a ficar visível deveria disparar um ping imediato"
  end

  # Regressão do bug "jogo trava se um jogador sai do navegador": mesmo com
  # RoomSweepJob avançando salas travadas no servidor (room_sweep_job_test.rb)
  # e o countdown pausando/retomando o ping por visibilidade (teste acima),
  # uma aba que ficou desconectada (segundo plano, rede caiu, laptop dormiu)
  # bem no momento em que a sala mudou de estado não tem como saber disso:
  # Turbo Streams via ActionCable é fire-and-forget, sem replay do que perdeu.
  # room_sync_controller.js cobre esse buraco fazendo um Turbo.visit completo
  # (GET normal em RoomsController#show, que sempre renderiza o estado certo)
  # sempre que a aba volta a ficar visível — não só nas views que já têm
  # room-countdown (round/results), mas na sala inteira, porque a transição
  # perdida também pode ser PRA DENTRO ou PRA FORA da sala de espera e do
  # placar final, que não têm countdown nenhum.
  #
  # Simulamos "perdeu o broadcast" avançando a sala DIRETO no banco via
  # update_all — pulando Room#advance!/RoomRound#finalize! (e portanto todo
  # broadcast_* que eles chamam) de propósito, pra garantir que o teste prova
  # a sincronização por GET e não por Turbo Stream.
  test "aba perdida durante uma sala em andamento sincroniza pro placar final ao voltar a ficar visível" do
    sala = criar_sala_em_andamento_com_rodada_ativa(total_rounds: 1)

    sign_in_via_ui(sala.host)
    visit room_path(sala)

    assert_text "Rodada 1 de 1"
    assert_selector "[data-controller='room-sync']"

    avancar_sala_direto_para_finished!(sala)

    # Nenhum broadcast chegou (bypassamos de propósito) — a página deve
    # continuar mostrando o estado antigo até a aba voltar a ficar visível.
    assert_text "Rodada 1 de 1"

    forcar_visibilidade_da_aba(hidden: true)
    forcar_visibilidade_da_aba(hidden: false)

    assert_text "Fim de jogo!"
  end

  # Mesma ideia do teste acima, mas cobrindo a transição PRA DENTRO do jogo a
  # partir da sala de espera — a outra ponta sem room-countdown citada no
  # comentário acima. Sem isso, um jogador que ficou de aba oculta enquanto o
  # host iniciava o jogo ficaria preso vendo "aguardando início" pra sempre.
  test "sala de espera perdida sincroniza pra rodada em andamento ao voltar a ficar visível" do
    sala = Room.create!(host: users(:fernanda), status: :waiting, difficulty: :medium,
      total_rounds: 1, round_duration_seconds: 600)
    sala.room_players.create!(user: users(:fernanda))

    sign_in_via_ui(sala.host)
    visit room_path(sala)

    assert_text "Compartilhe este código com seus amigos"

    avancar_sala_direto_para_rodada_1!(sala)

    # Nenhum broadcast chegou — a sala de espera continua na tela.
    assert_text "Compartilhe este código com seus amigos"

    forcar_visibilidade_da_aba(hidden: true)
    forcar_visibilidade_da_aba(hidden: false)

    assert_text "Rodada 1 de 1"
  end

  # Não cobrimos aqui o teto absoluto maxPingMinutes (30min por padrão): um
  # teste de verdade precisaria esperar 30 minutos reais, e simular isso
  # exigiria expor data-room-countdown-max-ping-minutes-value com um valor
  # baixo através de uma alteração em rooms/_round.html.erb só para permitir
  # o teste — o que distorceria a view de produção por causa de um
  # comportamento de backstop puro (o próprio código já documenta que
  # nenhuma rodada de verdade deveria precisar de mais que isso, e quem
  # cobre o caso real de sala abandonada além disso é o RoomSweepJob, já
  # testado em test/jobs/room_sweep_job_test.rb). A salvaguarda principal e
  # reportada pelo usuário — a pausa por visibilidade — é a testada acima.

  # Sessão única (não using_session): o que este teste prova que os testes
  # de controller não conseguem é a troca .email → .display_name renderizando
  # de verdade num navegador real, e o entry point "Jogar sem cadastro" (não
  # o form de senha) funcionando ponta a ponta numa sala. O mecanismo de
  # tempo real em si (broadcast entre duas sessões simultâneas) já está
  # coberto pelo teste com dois jogadores reais lá em cima — repetir isso
  # com dois visitantes seria caro e não provaria nada novo.
  test "visitante consegue entrar numa sala em andamento, chutar e ver seu apelido no resultado" do
    sala = criar_sala_em_andamento_com_rodada_ativa(total_rounds: 1)

    sign_in_como_visitante
    convidado = User.guest.order(:created_at).last
    sala.room_players.create!(user: convidado)

    visit room_path(sala)
    assert_text "Rodada 1 de 1"
    assert_no_text "Carregando mapa..."

    click_map_and_expect(/Chute registrado|Resultado da rodada/)

    # fernanda (host) ainda não chutou — só o convidado chutou até aqui —
    # então a rodada não deveria ter finalizado sozinha.
    assert_not sala.current_room_round.reload.finished?
  end

  private

  def forcar_visibilidade_da_aba(hidden:)
    visibility_state = hidden ? "hidden" : "visible"

    page.execute_script(<<~JS)
      Object.defineProperty(document, "hidden", { configurable: true, get: () => #{hidden} })
      Object.defineProperty(document, "visibilityState", { configurable: true, get: () => "#{visibility_state}" })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
  end

  def esperar_last_activity_mudar(sala, desde:, timeout: 6)
    Timeout.timeout(timeout, RuntimeError, "timeout esperando last_activity_at mudar") do
      loop do
        atual = sala.reload.last_activity_at
        break atual if atual != desde
        sleep 0.1
      end
    end
  end

  # Sala já em andamento com uma rodada ativa, sem passar pelo fluxo de
  # start_next_round! (que sorteia o país) — atribui countries(:atlantis)
  # diretamente para o teste ser determinístico, e usa round_duration_seconds
  # bem generoso pra rodada não vencer sozinha (o que trocaria #room_body
  # por rooms/_results antes de terminarmos de medir a pausa do countdown).
  def criar_sala_em_andamento_com_rodada_ativa(total_rounds: 3)
    sala = Room.create!(host: users(:fernanda), status: :waiting, difficulty: :medium,
      total_rounds: total_rounds, round_duration_seconds: 600)
    sala.room_players.create!(user: users(:fernanda))

    round = RoomRound.create!(room: sala, country: countries(:atlantis), round_number: 1, started_at: Time.current)
    sala.update!(current_room_round: round, status: :in_progress, current_round_number: 1)
    sala
  end

  # Leva uma sala em andamento direto pro status finished sem passar por
  # Room#advance!/RoomRound#finalize! — update_all não dispara callbacks nem
  # os broadcast_* que eles chamam, simulando fielmente "a sala avançou no
  # servidor mas esta aba nunca recebeu o Turbo Stream".
  def avancar_sala_direto_para_finished!(sala)
    RoomRound.where(id: sala.current_room_round_id)
             .update_all(status: RoomRound.statuses[:finished], ended_at: Time.current)
    Room.where(id: sala.id).update_all(status: Room.statuses[:finished])
  end

  # Mesma técnica acima, mas saindo da sala de espera direto pra rodada 1 —
  # RoomRound.create! não dispara nenhum broadcast por si só (só
  # Room#start_next_round! faz isso, e não é chamado aqui), então a criação
  # do registro sozinha já simula "o servidor avançou sem avisar esta aba".
  def avancar_sala_direto_para_rodada_1!(sala)
    round = RoomRound.create!(room: sala, country: countries(:atlantis), round_number: 1, started_at: Time.current)
    Room.where(id: sala.id).update_all(status: Room.statuses[:in_progress],
      current_round_number: 1, current_room_round_id: round.id)
  end

  def sign_in_via_ui(user)
    visit new_user_session_path

    fill_in "E-mail", with: user.email
    fill_in "Senha", with: "password123"
    click_on "Entrar"

    # `visit` não espera a navegação terminar como find/assert_text esperam
    # — sem essa sincronização, um `visit` logo em seguida pode disparar
    # antes do redirect do Devise (POST sign_in -> root) assentar, perdendo
    # o cookie de sessão recém-criado.
    assert_text user.email
  end

  def sign_in_como_visitante
    visit new_user_session_path
    click_on "Jogar sem cadastro"

    assert_text "Sair" # mesma sincronização de sign_in_via_ui, ver comentário lá
  end
end
