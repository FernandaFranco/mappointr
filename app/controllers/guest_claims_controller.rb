class GuestClaimsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_guest!

  # GET /guest_claim/new
  def new
  end

  # POST /guest_claim
  # Transforma a conta de visitante do usuário atual numa conta de verdade,
  # no lugar — sem criar um User novo, então game_rounds/room_players já
  # existentes continuam apontando pro mesmo id e o histórico da sessão não
  # se perde. Não usa update_with_password: o visitante não tem uma senha
  # de verdade que ele conheça pra confirmar, então confiamos em quem já
  # está logado nesta sessão como o próprio dono da conta.
  def create
    if current_user.update(claim_params.merge(guest: false, display_name: nil))
      # Trocar a senha muda authenticatable_salt, e o Warden invalida
      # sozinho qualquer sessão cujo salt não bata mais no próximo request —
      # sem isso, o usuário via a mensagem de sucesso por um instante e era
      # deslogado ao carregar a página seguinte. bypass_sign_in atualiza a
      # sessão pro salt novo sem repetir autenticação (o usuário já está
      # logado nesta sessão, só a credencial por trás dela mudou).
      bypass_sign_in(current_user)
      redirect_to root_path, notice: "Conta criada! Seu histórico de jogo foi mantido."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_guest!
    redirect_to root_path unless current_user.guest?
  end

  def claim_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
