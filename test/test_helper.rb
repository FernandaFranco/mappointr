ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

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
  # Sem login: fixa qual User a sessão representa via um dispatch real à
  # rota só de teste (ver TestSignInsController) — não escreve direto em
  # `session`, que só existe depois do primeiro request de verdade.
  def sign_in_as(user)
    get test_sign_in_path(user)
  end
end
