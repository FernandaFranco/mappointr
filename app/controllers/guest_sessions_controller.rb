class GuestSessionsController < ApplicationController
  # POST /guest_session
  # Cria (ou reaproveita) uma conta de visitante e loga com ela — sem senha,
  # sem formulário de cadastro. Reaproveitar via session[:current_guest_user_id]
  # evita criar um User novo a cada reload do botão "Jogar sem cadastro": é a
  # única proteção contra abuso que este fluxo tem, deliberadamente simples
  # (sem gem de rate limiting) — ver CLAUDE.md.
  def create
    guest = existing_guest || User.create_guest!
    session[:current_guest_user_id] = guest.id

    sign_in(guest)
    redirect_to root_path
  end

  private

  def existing_guest
    return nil unless session[:current_guest_user_id]

    User.guest.find_by(id: session[:current_guest_user_id])
  end
end
