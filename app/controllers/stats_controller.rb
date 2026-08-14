class StatsController < ApplicationController
  # Requer login para ver as próprias estatísticas
  before_action :authenticate_user!

  # GET /stats
  def show
    @user = current_user
  end
end
