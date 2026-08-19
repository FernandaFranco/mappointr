require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # config/environments/test.rb desliga a proteção CSRF pra simplificar
  # testes de controller/integration, mas isso faz csrf_meta_tags não
  # renderizar nada — e qualquer JS que leia esse meta tag (map_controller.js,
  # room_countdown_controller.js) quebra num navegador real. Testes de
  # sistema dirigem um navegador de verdade, então precisam se comportar
  # como produção/desenvolvimento nesse ponto.
  setup { ActionController::Base.allow_forgery_protection = true }
  teardown { ActionController::Base.allow_forgery_protection = false }
end
