require "application_system_test_case"

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
    # só pode ter chegado pelo broadcast_replace_to de #room_body.
    using_session(:guest) do
      assert_text "Rodada 1 de 1"
      find("#map-container").click
      assert_text(/Chute registrado|Resultado da rodada/)
    end

    using_session(:host) do
      find("#map-container").click
      assert_text "Resultado da rodada 1"
      # Prova que o novo Stimulus controller (room-result-map) realmente
      # inicializa num navegador real, sem erro de JS — os testes de
      # model/controller não conseguem verificar isso.
      assert_selector "[data-controller='room-result-map']"
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

  private

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
end
