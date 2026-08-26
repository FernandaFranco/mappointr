require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Sem isso, sessões nomeadas (using_session(:host)/(:guest), usadas nos
  # testes de sala) carregam cookie de login de um método de teste pro
  # próximo dentro da mesma execução — a MESMA janela/cookie jar do
  # Selenium é reaproveitada entre test methods, então se um teste anterior
  # deixou fernanda logada em :host, o próximo teste que tentar
  # sign_in_via_ui(fernanda) em :host cai direto no "You are already
  # signed in." do Devise, que redireciona pra longe do formulário — daí o
  # field "E-mail" nunca aparece. Isso só se manifestava rodando a suíte
  # inteira (nunca um arquivo sozinho com poucos usos de using_session), e
  # o teste que falhava mudava a cada rodada conforme a ordem aleatória do
  # --seed. Não era timing: aumentar Capybara.default_max_wait_time não
  # ajudava em nada, porque o campo genuinamente não estava na página.
  teardown { Capybara.reset_sessions! }

  # config/environments/test.rb desliga a proteção CSRF pra simplificar
  # testes de controller/integration, mas isso faz csrf_meta_tags não
  # renderizar nada — e qualquer JS que leia esse meta tag (map_controller.js,
  # room_countdown_controller.js) quebra num navegador real. Testes de
  # sistema dirigem um navegador de verdade, então precisam se comportar
  # como produção/desenvolvimento nesse ponto.
  setup { ActionController::Base.allow_forgery_protection = true }
  teardown { ActionController::Base.allow_forgery_protection = false }

  # "Node with given id does not belong to the document" (-32000) é um bug
  # conhecido do ChromeDriver/CDP, não da nossa aplicação: o node id que o
  # Capybara guardou fica inválido entre localizar o elemento e checar
  # visibilidade/clicar nele. Reproduz principalmente clicando no mapa
  # (#map-container) logo depois dele renderizar — o Leaflet segue mexendo
  # no próprio DOM (tiles chegando de forma assíncrona) mesmo depois do
  # placeholder "Carregando mapa..." já ter sumido, então nem esperar mais
  # elimina a corrida (confirmado: reproduziu até num teste com hard
  # navigation e um clique só, sem Turbo Stream nem broadcast nenhum
  # envolvido). Não tem timing que resolva de vez; o padrão aceito pra esse
  # bug é tentar de novo.
  def retry_on_stale_node(times: 3)
    yield
  rescue Selenium::WebDriver::Error::UnknownError => e
    raise unless e.message.include?("does not belong to the document")

    times -= 1
    raise if times <= 0

    retry
  end

  # Clica no mapa (#map-container) pra registrar um chute e confirma o
  # texto esperado depois — precisam estar juntos num retry só porque o bug
  # do ChromeDriver acima pode acontecer tanto no clique quanto na
  # conferência seguinte. Só clica de novo se +pattern+ ainda não estiver
  # na página: assim uma retentativa nunca reenvia o mesmo chute (em sala,
  # chutar duas vezes na mesma rodada vira erro de validação, não um
  # segundo chute silencioso — ver RoomGuessesController).
  def click_map_and_expect(pattern)
    retry_on_stale_node do
      find("#map-container").click unless page.has_text?(pattern)
      assert_text(pattern)
    end
  end
end
