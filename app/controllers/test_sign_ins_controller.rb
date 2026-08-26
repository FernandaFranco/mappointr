# Só existe em teste (ver config/routes.rb) — deixa um teste de sistema
# escolher qual User uma sessão de browser representa, algo que um teste de
# integração faz direto em `session[...]`, mas Capybara/Selenium não
# compartilha memória com o processo de teste.
class TestSignInsController < ApplicationController
  def create
    session[:user_id] = params[:user_id]
    redirect_to root_path
  end
end
