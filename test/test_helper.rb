ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Sem eager_load em test local (config.eager_load = ENV["CI"].present?), as
# rotas só carregam de verdade no primeiro dispatch HTTP real — e até lá,
# Devise.mappings fica vazio. Devise::Test::IntegrationHelpers#sign_in não
# faz um dispatch de verdade (é Warden puro), então um teste que chama
# sign_in antes de qualquer get/post, se for o primeiro a rodar no processo
# (comum em arquivos de teste pequenos/isolados, onde a ordem aleatória do
# --seed tem mais chance de expor isso), falhava com "Could not find a valid
# mapping" — Devise.mappings ainda vazio. Nunca aparecia no CI (eager_load
# força tudo a carregar no boot), só localmente. Forçar as rotas aqui, uma
# vez, antes de qualquer teste rodar, elimina a corrida de vez.
Rails.application.reload_routes!

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
