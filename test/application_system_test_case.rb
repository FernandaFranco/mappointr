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
end
