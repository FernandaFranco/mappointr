class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_user
  helper_method :current_user

  private

  # Não existe login: todo visitante vira um User na primeira request e
  # session[:user_id] é a única identidade que o app conhece dali em diante.
  def set_current_user
    @current_user = User.find_by(id: session[:user_id])
    @current_user ||= User.create_player!.tap { |user| session[:user_id] = user.id }
  end

  def current_user
    @current_user
  end
end
